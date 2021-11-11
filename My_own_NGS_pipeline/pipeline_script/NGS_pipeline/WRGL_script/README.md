 WCEP and WRGL analysis scripts
================================

Scripts for the analyis of WCEP exome and WRGL panels samples on Iridis

Usage
--------

Local copies of the scripts and WRGLPipeline.config are kept on Z:\WRGLPipeline\Panel
These are automatically uploaded and run when the MiSeq run completes.
No manual intervention is required

pipeline_runner
---------------

The pipeline runner script starts and monitors qsub jobs, it runs the pipeline (hence the name).
Using this vs individually (and chain) qsubbing scripts means that we can run scripts which
require internet access as a process is kept running on the internet-enabled login node.

Update history
--------------

### 2.21

 * Adds pipeline_runner.sh to run QC scripts on login node
 * Adds call to backup run ready for Amazon Glacier upload (not yet implemented)

### 2.2

 * Combined scripts with the WRGL panels
 * Introduced dynamic PBS resource requests

### 2.1

 * Introduced config file to define pipeline parameters (software paths etc.)
