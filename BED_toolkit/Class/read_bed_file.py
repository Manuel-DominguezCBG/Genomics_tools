'''
Read bed files and store data in a dict
Created by Manuel Dominguez
'''
import sys

class Read_file():
    '''
    Load bed data
    '''
    def __init__(self, file_path): 
        self.file_path = file_path

    def load_data(self):
        '''Load data from file
        Create a empty dict,
        open the file and read line by line
        Recognise the lines that contains the data, 
        check that this data satisfyies the minimun
        split this lines and save this in chromosomes, start and end positions
        Per iteration, store interger position in a list
        save these lists in the chromosome that belong to
        Return a dict
        'chr1': [[1, 2], [3, 4], [5, 6], [7, 8]], 'chr20': [[1, 2], [3, 4]] ...
        '''
        chr2position = {}
        with open(self.file_path) as f:
            for line in f.readlines():
                star_end_list = []
                if line.startswith(('chr',"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21","Y","X")):

                    # Validation to ensure structure of bed file is what expected
                    assert (len(line.split())) >= 3, 'Bed file has not three three minimus columns "chr", "start" "end" '
                    chr, start, end = line.split()[:3]
                    
                    try: # A bit of validation
                        star_end_list = [int(start), int(end)]
                    except: 
                        print("Don't pass validation. End or start position are not interger",chr, start, end)
                        sys.exit(1) # To stop running the script and avoid future errors outputs

                    if chr in chr2position.keys():
                        chr2position[chr].append(star_end_list)
                    else:
                        chr2position[chr] = [star_end_list]
        return chr2position
