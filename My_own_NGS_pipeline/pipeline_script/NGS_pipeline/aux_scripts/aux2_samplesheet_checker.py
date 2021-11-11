#!/usr/bin/env python3

import sys
import os
from stat import S_ISFIFO


class SampleSheet(object):
    """
    Ensures that a samplesheet csv is complete for exome analysis.
    Takes the csv and a run ID as arguments (run ID is optional)
    Uses the run ID as the "description" and Sample_Project fields.
    This means we can now run the exome analysis with no manual editing
    of the WCEP.config file.
    """

    def __init__(self, fname=sys.stdin, runid=None):
        self.fname = fname
        self.runid = runid

        self.process_file(self.fname, self.runid)

    @staticmethod
    def process_file(fname, runid=None):
        """
        Process each line of the samplesheet CSV
        Identify new sections
        Store data lines in relevant section dict
        """

        # Record if there is an existing analysis defined in the Data section
        # this needs to be defined outside the for loop or it gets overwritten
        # and ignored
        existinganalysis = True
        for line in fname:
            # this will exclude blank lines
            if line.strip():
                line = line.strip()

                # process section names
                if line.startswith("["):
                    section = line.lstrip("[").rstrip("]")
                    if section != "Header":
                        print("")
                    print(line)
                else:

                    # process data lines
                    line = line.split(",")

                    # if there is no description, use the experiment name
                    # if there is no experiment name, use a default value
                    # "EXOME"
                    if line[0] == "Experiment Name":
                        if line[1] == "":
                            expname = "EXOME"
                        else:
                            expname = line[1]
                        print("Experiment Name,{0}".format(expname))
                    elif line[0] == "Description":
                        # Always overwrite an existing description with
                        # the run ID if given
                        if line[1] == "":
                            description = runid if runid else expname
                        else:
                            description = runid if runid else line[1]
                        print("Description,{0}".format(description))

                    # In the analysis section, if a run ID is provided
                    # update the analysis path to the ROI bed file that
                    # will be created during analysis. This can be downloaded
                    # automatically and remove a current manual step
                    elif section == "Analysis":
                        analysis = line[0]
                        if runid:
                            line[1] = (
                                fr"\\sdh-public\GENETICSDATA"
                                fr"\Illumina\MiSeqOutput\{runid}"
                                fr"\Panel2.2\{runid}_ROIs.bed"
                            )
                        print(",".join(line))

                    # The Data section needs special handling. We need to
                    # insert the description into the sample_project column
                    # and also add an analysis column if missing
                    elif section == "Data":
                        # This indicates it is the header line
                        if line[0] == "Sample_ID":
                            # If there isn't a analysis column, add one
                            if "Analysis" not in line:
                                existinganalysis = False
                                line.append("Analysis")
                            print(",".join(line))
                        else:
                            # Add the analysis to the sample if necessary
                            if not existinganalysis:
                                line.append(analysis)
                            # Add to both Sample_project and Description cols
                            line[8] = description
                            line[9] = description
                            print(",".join(line))

                    # Everything else we can just print as csv
                    else:
                        print(",".join(line))


if __name__ == "__main__":

    if len(sys.argv) == 3:
        try:
            # samplesheet csv file name and run id user specified
            with open(sys.argv[1], "r") as fname:
                SampleSheet(fname=fname, runid=sys.argv[2])
        except IOError:
            with open(sys.argv[2], "r") as fname:
                SampleSheet(fname=fname, runid=sys.argv[1])

    elif len(sys.argv) == 2:
        try:
            with open(sys.argv[1], "r") as fname:
                SampleSheet(fname=fname)
        except IOError:
            if S_ISFIFO(os.fstat(0).st_mode):
                SampleSheet(fname=sys.stdin, runid=sys.argv[1])
    else:
        if S_ISFIFO(os.fstat(0).st_mode):
            SampleSheet(fname=sys.stdin)
