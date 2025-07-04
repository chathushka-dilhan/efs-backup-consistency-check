import json
import os
import boto3
import time
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

# Environment variables (set in Terraform)
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')
EFS_ID = os.environ.get('EFS_ID')
VPC_ID = os.environ.get('VPC_ID')
SUBNET_IDS = json.loads(os.environ.get('SUBNET_IDS', '[]'))
SECURITY_GROUP_IDS = json.loads(os.environ.get('SECURITY_GROUP_IDS', '[]'))
ECS_CLUSTER_NAME = os.environ.get('ECS_CLUSTER_NAME')
ECS_TASK_DEFINITION_ARN = os.environ.get('ECS_TASK_DEFINITION_ARN')
ECS_CONTAINER_NAME = os.environ.get('ECS_CONTAINER_NAME')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
PROJECT_NAME = os.environ.get('PROJECT_NAME')

def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")

    backup_job_id = None
    resource_arn = None
    recovery_point_arn = None

    # Extract information from AWS Backup Completion Event
    if 'detail' in event and event['detail']['state'] == 'COMPLETED':
        backup_job_id = event['detail']['backupJobId']
        resource_arn = event['detail']['resourceArn']
        recovery_point_arn = event['detail']['recoveryPointArn']
        logger.info(f"AWS Backup Job {backup_job_id} for {resource_arn} completed. Recovery Point ARN: {recovery_point_arn}")
    else:
        logger.warning("Event is not a successful AWS Backup completion event for EFS. Exiting.")
        return {
            'statusCode': 200,
            'body': json.dumps('Not a relevant backup completion event.')
        }

    efs_client = boto3.client('efs')
    ecs_client = boto3.client('ecs')
    backup_client = boto3.client('backup')
    s3_client = boto3.client('s3')
    sns_client = boto3.client('sns')

    temp_efs_id = None
    temp_efs_access_point_id = None
    ecs_task_arn = None

    try:
        # --- Step 1: Initiate EFS Restore ---
        logger.info(f"Initiating restore for recovery point: {recovery_point_arn}")
        restore_job = backup_client.start_restore_job(
            RecoveryPointArn=recovery_point_arn,
            Metadata={
                'file-system-id': EFS_ID, # This is the original EFS ID, not the new one
                'Encrypted': 'false', # For simplicity, can be 'true' if needed
                'PerformanceMode': 'generalPurpose', # Or 'maxIO'
                'ThroughputMode': 'bursting', # Or 'provisioned'
                'CreationInfo': '{"OwnerUid":0,"OwnerGid":0,"Permissions":"0755"}',
                'EnableAutomaticBackups': 'false',
            },
            ResourceType='EFS'
        )
        restore_job_id = restore_job['RestoreJobId']
        logger.info(f"Restore job started: {restore_job_id}")

        # Wait for restore job to complete
        while True:
            response = backup_client.describe_restore_job(RestoreJobId=restore_job_id)
            status = response['RestoreJob']['Status']
            logger.info(f"Restore job status: {status}")
            if status == 'COMPLETED':
                temp_efs_id = response['RestoreJob']['CreatedResourceArn'].split('/')[-1]
                logger.info(f"EFS Restore completed. Temporary EFS ID: {temp_efs_id}")
                break
            elif status == 'FAILED':
                raise Exception(f"EFS Restore job failed: {response['RestoreJob']['StatusMessage']}")
            time.sleep(30) # Wait 30 seconds before checking again

        # --- Step 2: Create EFS Access Point for Temporary EFS ---
        logger.info(f"Creating access point for temporary EFS {temp_efs_id}")
        access_point_response = efs_client.create_access_point(
            FileSystemId=temp_efs_id,
            PosixUser={
                'Uid': 0,
                'Gid': 0
            },
            RootDirectory={
                'Path': '/'
            },
            Tags=[
                {'Key': 'Name', 'Value': f'{PROJECT_NAME}-temp-ap'},
                {'Key': 'Temporary', 'Value': 'true'},
                {'Key': 'Purpose', 'Value': 'EFSBackupVerification'}
            ]
        )
        temp_efs_access_point_id = access_point_response['AccessPoint']['AccessPointId']
        logger.info(f"Access Point {temp_efs_access_point_id} created for {temp_efs_id}.")


        # --- Step 3: Run ECS Fargate Task to Generate Manifest ---
        logger.info("Running ECS Fargate task to generate manifest for restored EFS...")
        run_task_response = ecs_client.run_task(
            cluster=ECS_CLUSTER_NAME,
            launchType='FARGATE',
            taskDefinition=ECS_TASK_DEFINITION_ARN,
            count=1,
            platformVersion='LATEST',
            networkConfiguration={
                'awsvpcConfiguration': {
                    'subnets': SUBNET_IDS,
                    'securityGroups': SECURITY_GROUP_IDS,
                    'assignPublicIp': 'DISABLED' # No public IP needed
                }
            },
            overrides={
                'containerOverrides': [
                    {
                        'name': ECS_CONTAINER_NAME,
                        'command': [
                            '--mount-point', '/mnt/efs', # Mount point inside container
                            '--output-filename', '/tmp/restored_efs_manifest.json',
                            '--s3-bucket', S3_BUCKET_NAME,
                            '--s3-prefix', 'restored_manifests'
                        ]
                    }
                ]
            },
            # EFS volume configuration for the task
            # The volume is defined in the task definition, here we link to the specific EFS and AP
            # This is implicitly handled by the task definition's volume configuration
            # and the access point created above.
        )

        ecs_task_arn = run_task_response['tasks'][0]['taskArn']
        logger.info(f"ECS Fargate task started: {ecs_task_arn}. Waiting for it to complete...")

        # Wait for ECS task to complete
        while True:
            describe_tasks_response = ecs_client.describe_tasks(
                cluster=ECS_CLUSTER_NAME,
                tasks=[ecs_task_arn]
            )
            task_status = describe_tasks_response['tasks'][0]['lastStatus']
            logger.info(f"ECS task status: {task_status}")
            if task_status == 'STOPPED':
                break
            elif task_status == 'FAILED': # Or other failure states
                raise Exception(f"ECS Fargate task failed: {describe_tasks_response['tasks'][0]['stoppedReason']}")
            time.sleep(30) # Wait 30 seconds before checking again

        # --- Step 4: Compare Manifests (assuming original manifest is already in S3) ---
        original_manifest_key = f"original_manifests/efs_original_manifest_{EFS_ID}.json" # Example key
        restored_manifest_key = f"restored_manifests/restored_efs_manifest.json" # Key from ECS task

        logger.info(f"Downloading original manifest from s3://{S3_BUCKET_NAME}/{original_manifest_key}")
        original_manifest_obj = s3_client.get_object(Bucket=S3_BUCKET_NAME, Key=original_manifest_key)
        original_manifest = json.loads(original_manifest_obj['Body'].read().decode('utf-8'))

        logger.info(f"Downloading restored manifest from s3://{S3_BUCKET_NAME}/{restored_manifest_key}")
        restored_manifest_obj = s3_client.get_object(Bucket=S3_BUCKET_NAME, Key=restored_manifest_key)
        restored_manifest = json.loads(restored_manifest_obj['Body'].read().decode('utf-8'))

        discrepancies = compare_efs_manifests(original_manifest, restored_manifest)

        if any(discrepancies.values()):
            message = "EFS Backup Consistency Check FAILED: Discrepancies found."
            logger.error(message)
            logger.error(json.dumps(discrepancies, indent=2))
            if SNS_TOPIC_ARN:
                sns_client.publish(
                    TopicArn=SNS_TOPIC_ARN,
                    Subject="EFS Backup Consistency Alert: Discrepancies Found!",
                    Message=json.dumps(discrepancies, indent=2)
                )
        else:
            message = "EFS Backup Consistency Check PASSED: No discrepancies found. The backup is consistent."
            logger.info(message)
            if SNS_TOPIC_ARN:
                sns_client.publish(
                    TopicArn=SNS_TOPIC_ARN,
                    Subject="EFS Backup Consistency Alert: Success",
                    Message=message
                )

    except Exception as e:
        logger.error(f"An error occurred during the consistency check: {e}", exc_info=True)
        if SNS_TOPIC_ARN:
            sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject="EFS Backup Consistency Alert: Process Failed",
                Message=f"An error occurred during EFS backup consistency check: {e}"
            )
    finally:
        # --- Step 5: Cleanup ---
        if ecs_task_arn:
            logger.info(f"Stopping ECS task: {ecs_task_arn}")
            try:
                ecs_client.stop_task(cluster=ECS_CLUSTER_NAME, task=ecs_task_arn)
            except Exception as e:
                logger.warning(f"Could not stop ECS task {ecs_task_arn}: {e}")

        if temp_efs_access_point_id:
            logger.info(f"Deleting temporary EFS access point: {temp_efs_access_point_id}")
            try:
                efs_client.delete_access_point(AccessPointId=temp_efs_access_point_id)
            except Exception as e:
                logger.warning(f"Could not delete temporary EFS access point {temp_efs_access_point_id}: {e}")

        if temp_efs_id:
            logger.info(f"Deleting temporary EFS file system: {temp_efs_id}")
            try:
                efs_client.delete_file_system(FileSystemId=temp_efs_id)
            except Exception as e:
                logger.warning(f"Could not delete temporary EFS {temp_efs_id}: {e}")

    return {
        'statusCode': 200,
        'body': json.dumps('EFS backup consistency check process initiated/completed.')
    }

def compare_efs_manifests(original_manifest, backup_manifest):
    """
    Compares two EFS manifests and reports discrepancies.
    This is a simplified version of the separate comparison script.
    """
    discrepancies = {
        "files_only_in_original": [],
        "files_only_in_backup": [],
        "size_mismatches": [],
        "content_mismatches": []
    }

    original_files = {item['path']: item for item in original_manifest}
    backup_files = {item['path']: item for item in backup_manifest}

    for path, original_data in original_files.items():
        if path not in backup_files:
            discrepancies["files_only_in_original"].append(path)
        else:
            backup_data = backup_files[path]
            if original_data['size'] != backup_data['size']:
                discrepancies["size_mismatches"].append({
                    "path": path,
                    "original_size": original_data['size'],
                    "backup_size": backup_data['size']
                })
            if original_data['sha256'] != backup_data['sha256']:
                discrepancies["content_mismatches"].append({
                    "path": path,
                    "original_sha256": original_data['sha256'],
                    "backup_sha256": backup_data['sha256']
                })

    for path in backup_files:
        if path not in original_files:
            discrepancies["files_only_in_backup"].append(path)

    return discrepancies