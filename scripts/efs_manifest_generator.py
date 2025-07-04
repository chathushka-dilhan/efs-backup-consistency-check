# This script generates a manifest of files in an EFS mount point, including their size and SHA256 hash.
# It can also upload the manifest to an S3 bucket if specified.

import os
import hashlib
import json
import argparse
import logging
import boto3

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def calculate_sha256(filepath, chunk_size=8192):
    """Calculates the SHA256 hash of a file."""
    sha256_hash = hashlib.sha256()
    try:
        with open(filepath, "rb") as f:
            for byte_block in iter(lambda: f.read(chunk_size), b""):
                sha256_hash.update(byte_block)
        return sha256_hash.hexdigest()
    except IOError as e:
        logging.error(f"Error reading file {filepath}: {e}")
        return None

def generate_efs_manifest(mount_point, output_filename, s3_bucket=None, s3_prefix=None):
    """
    Generates a manifest of files in the EFS mount point, including size and SHA256 hash.
    Optionally uploads the manifest to S3.
    """
    manifest = []
    logging.info(f"Starting manifest generation for EFS at: {mount_point}")

    if not os.path.exists(mount_point):
        logging.error(f"Mount point '{mount_point}' does not exist. Please ensure EFS is mounted.")
        return

    for root, _, files in os.walk(mount_point):
        for filename in files:
            filepath = os.path.join(root, filename)
            try:
                # Get file stats
                stats = os.stat(filepath)
                file_size = stats.st_size
                modification_time = stats.st_mtime # Unix timestamp

                # Calculate SHA256 hash
                file_hash = calculate_sha256(filepath)
                if file_hash is None:
                    logging.warning(f"Skipping {filepath} due to hashing error.")
                    continue

                # Store relative path
                relative_path = os.path.relpath(filepath, mount_point)

                manifest.append({
                    "path": relative_path,
                    "size": file_size,
                    "mtime": modification_time,
                    "sha256": file_hash
                })
                logging.debug(f"Added {relative_path} to manifest.")

            except OSError as e:
                logging.error(f"Error processing file {filepath}: {e}")
                continue

    logging.info(f"Manifest generation complete. Found {len(manifest)} files.")

    # Save manifest to local file
    try:
        with open(output_filename, 'w') as f:
            json.dump(manifest, f, indent=4)
        logging.info(f"Manifest saved locally to: {output_filename}")
    except IOError as e:
        logging.error(f"Error saving manifest to local file {output_filename}: {e}")
        return

    # Upload to S3 if bucket is provided
    if s3_bucket:
        try:
            s3_client = boto3.client('s3')
            s3_key = os.path.join(s3_prefix, os.path.basename(output_filename)) if s3_prefix else os.path.basename(output_filename)
            s3_client.upload_file(output_filename, s3_bucket, s3_key)
            logging.info(f"Manifest uploaded to S3://{s3_bucket}/{s3_key}")
        except Exception as e:
            logging.error(f"Error uploading manifest to S3: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate a manifest of EFS files with SHA256 hashes.")
    parser.add_argument("--mount-point", required=True, help="The EFS mount point directory.")
    parser.add_argument("--output-filename", required=True, help="The name of the output JSON manifest file.")
    parser.add_argument("--s3-bucket", help="Optional: S3 bucket name to upload the manifest.")
    parser.add_argument("--s3-prefix", default="", help="Optional: S3 prefix (folder) for the uploaded manifest.")

    args = parser.parse_args()

    generate_efs_manifest(
        mount_point=args.mount_point,
        output_filename=args.output_filename,
        s3_bucket=args.s3_bucket,
        s3_prefix=args.s3_prefix
    )
