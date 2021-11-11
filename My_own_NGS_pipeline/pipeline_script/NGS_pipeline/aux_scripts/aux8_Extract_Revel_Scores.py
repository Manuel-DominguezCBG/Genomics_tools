#!/usr/bin/env python3

"""
Extract the REVEL field from the VEP CSQ= annotation
and add it back into the VCF INFO as 'REVEL='
"""
import sys
from pathlib import Path


def read_vcf_file(fname: Path) -> None:
    """read the VCF header and get the CSQ field sections"""
    with open(fname) as f:
        for line in f:
            line = line.rstrip()
            if line.startswith("#"):
                # First, these lines can all be printed
                if "CSQ" in line:
                    csq_headers = process_vep_csq(line)
                    # continue to avoid printing CSQ INFO header
                    continue
                if "EFF" in line:
                    # DEV: Not yet implemented
                    pass
                if "#CHROM" in line:
                    vcf_headers = process_vcf_headers(line)
                    # Print the REVEL header line here,
                    # so that it appears just above the header line
                    print(
                        (
                            "##INFO=<ID=REVEL,Number=1,Type=Float,"
                            'Description="Rare Exome Variant'
                            'Ensemble Learner">'
                        )
                    )
                # print the header line
                print(line)
            else:
                # Split the variant up into the VCF columns,
                # creating a dict for ease of access
                variant: dict = dict(zip(vcf_headers, line.split()))
                # Split the INFO column into it's constituent fields
                variant["INFO"] = process_info_field(variant["INFO"])

                # Split out the VEP CSQ field components, so we can access
                # the REVEL score. There are multiple transcripts but the
                # score appears to be consistent regardless so we just need
                # to ensure that a score is returned
                variant["INFO"]["CSQ"] = extract_csq(variant, csq_headers)

                # Pull out the REVEL score into the INFO field
                variant = extract_revel(variant)

                # Convert the INFO dict back into a string
                infolist = [x for x in variant["INFO"].values()]
                variant["INFO"] = ";".join(infolist)
                print("\t".join(variant.values()))


def extract_csq(variant: dict, csq_headers: list) -> dict:
    """
    Extract the correct transcript annotation from the CSQ field.
    Return parsed as a dictionary with the relevant keys from the CSQ header
    """
    # Split out the multiple CSQ annotations, comma separated
    for csq in variant["INFO"]["CSQ"].split(","):
        # Create a dict for easy access
        csq_dict = dict(zip(csq_headers, csq.split("|")))
        # If there's a REVEL score return it, regardless of transcript
        # REVEL score is by genomic position and does not change with
        # transcript so we don't need to check the transcript.
        if csq_dict["REVEL"] != "":
            return csq_dict
    # If there is no REVEL score for any CSQ annotation, return the last one
    # and the score will be defaulted to 0, also print a warning message
    print(
        (
            f"WARNING: No REVEL score for variant {variant['CHROM']}:"
            f"{variant['POS']}{variant['REF']}>{variant['ALT']}"
        ), file=sys.stderr
    )
    return csq_dict


def extract_revel(variant: dict) -> dict:
    """
    Extract the REVEL score from the CSQ field, and add it back as a
    pure INFO field If there isn't a score, e.g. not a coding variant,
    set the score to 0 to avoid unanticipated effects on software filters.
    """
    # The default value to return if no REVEL score found
    # Must be accepted by the Alissa filter, but also obvious to the analyst
    # Since REVEL is 0-1 scale, 999 should be pretty clearly abnormal!
    REVEL_DEFAULT = 999
    # Get the REVEL score and check if it's missing or not
    revel = variant["INFO"]["CSQ"]["REVEL"]
    if revel == "":
        revel = REVEL_DEFAULT
    # Add REVEL score back into VCF as a new field
    variant["INFO"]["REVEL"] = f"REVEL={revel}"
    # Remove the CSQ field as we don't need it and it would be
    # work to translate it back to a list.
    variant["INFO"].pop("CSQ", None)
    return variant


def process_info_field(line: str) -> dict:
    """
    Split the VCF info field into a dict for easy access
    """
    linelist = line.split(";")
    info_dict = {}
    for item in linelist:
        try:
            item_split = item.split("=")
            info_dict[item_split[0]] = item
        except IndexError:
            info_dict[item_split[0]] = item
    return info_dict


def process_vcf_headers(line: str) -> list:
    """
    Get the list of VCF column headers so that each var can be processed easily
    with zip
    """
    line = line.lstrip("#")
    linelist = line.split()
    return linelist


def process_vep_csq(line: str) -> list:
    line = line.rstrip(">").rstrip('"')
    linelist = line.split("|")
    linelist[0] = linelist[0].split(" ")[-1]
    return linelist


def process_snpeff_eff(line: str) -> str:
    return line


if __name__ == "__main__":
    # TODO: Test args are correct

    fname = Path(sys.argv[1])
    read_vcf_file(fname)
