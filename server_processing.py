#!/usr/bin/env python3
"""
Simple server to process photogrammetry images using Apple's photogrammetry CLI tool.
Run this on your server at 10.10.97.20

Requirements:
- macOS with photogrammetry CLI tool
- Flask: pip install flask

Usage:
    python3 server_processing.py
"""

from flask import Flask, request, jsonify, send_file
import os
import uuid
import subprocess
import threading
import time
from pathlib import Path
import shutil

app = Flask(__name__)

# Health check endpoint for connection testing
@app.route('/status/test', methods=['GET'])
def health_check():
    return jsonify({"status": "Server is running"}), 200

# Storage directories
UPLOAD_DIR = Path("/tmp/photogrammetry_uploads")
PROCESSING_DIR = Path("/tmp/photogrammetry_processing")
RESULTS_DIR = Path("/tmp/photogrammetry_results")

# Create directories
for dir_path in [UPLOAD_DIR, PROCESSING_DIR, RESULTS_DIR]:
    dir_path.mkdir(parents=True, exist_ok=True)

# Job status tracking
jobs = {}

@app.route('/upload', methods=['POST'])
def upload():
    """Upload images and start processing"""
    try:
        job_id = str(uuid.uuid4())
        job_dir = UPLOAD_DIR / job_id
        job_dir.mkdir(exist_ok=True)
        
        # Get capture mode
        mode = request.form.get('mode', 'object')
        is_area_mode = (mode == 'area')
        
        # Save uploaded images
        image_files = []
        for key, file in request.files.items():
            if key == 'images':
                filename = file.filename
                filepath = job_dir / filename
                file.save(str(filepath))
                image_files.append(filepath)
        
        if not image_files:
            return jsonify({"error": "No images uploaded"}), 400
        
        # Initialize job status
        jobs[job_id] = {
            "status": "processing",
            "progress": 0.0,
            "stage": "Starting processing...",
            "job_dir": str(job_dir),
            "output_file": None
        }
        
        # Start processing in background thread
        thread = threading.Thread(
            target=process_images,
            args=(job_id, job_dir, image_files, is_area_mode)
        )
        thread.daemon = True
        thread.start()
        
        return jsonify({"jobId": job_id, "message": "Upload successful"}), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

def process_images(job_id, job_dir, image_files, is_area_mode):
    """Process images using photogrammetry CLI"""
    try:
        jobs[job_id]["stage"] = "Preparing images..."
        jobs[job_id]["progress"] = 0.1
        
        # Check if photogrammetry CLI tool exists
        try:
            result = subprocess.run(["which", "photogrammetry"], 
                                  capture_output=True, text=True, timeout=2)
            if result.returncode != 0:
                raise FileNotFoundError("photogrammetry CLI tool not found")
        except (FileNotFoundError, subprocess.TimeoutExpired):
            jobs[job_id]["status"] = "failed"
            jobs[job_id]["stage"] = "Error: photogrammetry CLI tool not installed. Please use Swift server instead (see ServerProcessingServer/README.md)"
            jobs[job_id]["progress"] = 0.0
            return
        
        # Create output file
        output_file = RESULTS_DIR / f"{job_id}.usdz"
        
        # Build photogrammetry command
        # Note: Adjust path to photogrammetry tool if needed
        cmd = [
            "photogrammetry",
            str(job_dir),
            str(output_file)
        ]
        
        # Add area mode flag if needed (if supported)
        if is_area_mode:
            # Some versions may support --no-object-masking
            pass
        
        jobs[job_id]["stage"] = "Processing images..."
        jobs[job_id]["progress"] = 0.2
        
        # Run photogrammetry
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        # Monitor progress (simplified - you can parse output for real progress)
        while process.poll() is None:
            time.sleep(1)
            # Update progress (simplified - in real implementation, parse output)
            if jobs[job_id]["progress"] < 0.9:
                jobs[job_id]["progress"] += 0.01
        
        stdout, stderr = process.communicate()
        
        if process.returncode == 0 and output_file.exists():
            jobs[job_id]["status"] = "completed"
            jobs[job_id]["progress"] = 1.0
            jobs[job_id]["stage"] = "Processing complete"
            jobs[job_id]["output_file"] = str(output_file)
        else:
            jobs[job_id]["status"] = "failed"
            jobs[job_id]["stage"] = f"Processing failed: {stderr[:100]}"
            
    except Exception as e:
        jobs[job_id]["status"] = "failed"
        jobs[job_id]["stage"] = f"Error: {str(e)}"

@app.route('/status/<job_id>', methods=['GET'])
def status(job_id):
    """Get processing status"""
    if job_id not in jobs:
        return jsonify({"error": "Job not found"}), 404
    
    job = jobs[job_id]
    return jsonify({
        "status": job["status"],
        "progress": job["progress"],
        "stage": job["stage"]
    }), 200

@app.route('/download/<job_id>', methods=['GET'])
def download(job_id):
    """Download processed model"""
    if job_id not in jobs:
        return jsonify({"error": "Job not found"}), 404
    
    job = jobs[job_id]
    if job["status"] != "completed" or not job["output_file"]:
        return jsonify({"error": "Job not completed"}), 400
    
    output_file = Path(job["output_file"])
    if not output_file.exists():
        return jsonify({"error": "Output file not found"}), 404
    
    return send_file(
        str(output_file),
        as_attachment=True,
        download_name=f"{job_id}.usdz",
        mimetype='model/vnd.usdz+zip'
    )

if __name__ == '__main__':
    print("=" * 60)
    print("Starting photogrammetry processing server on THIS COMPUTER")
    print("Server will be accessible at: http://192.168.1.78:1100")
    print("Make sure iPhone is on the same WiFi network")
    print("=" * 60)
    app.run(host='0.0.0.0', port=1100, debug=True)

