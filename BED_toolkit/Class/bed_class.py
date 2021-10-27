
'''
Read BED files and do basic checking

'''
import pandas as pd

class Read_file():
    '''
    Load bed data
    '''
    def __init__(self, file_path): 
        self.file_path = file_path
        
    def load_data(self):
        '''
        Load data from file 
        '''
        sequence = {}
        with open(self.file_path) as f:
            for line in f:
                star_end_list = []
                if line.startswith('chr'):
                    chr, start, end = line.split()[:3]
                    star_end_list.append(start)
                    star_end_list.append(end)
                    sequence[chr] = star_end_list
        return sequence
                    
            
            


class Sequence:  
    '''
    Basic tools to analysed DNA sequence
    '''
    def __init__(self, DNA): 
        '''
        Stores original sequence
        '''
        try:
            self.DNA = self.validation(DNA)
        except AssertionError:
            print("Do not pass validation")
    def test(self):
        return self.DNA
    def validation(self, sequence):
        """
      Some basic validation.
        """
        # Check if chr values are string
        assert all(isinstance(key, str) for key in sequence.keys()),"The key of the dict are not string"
        # Check if Start and End  are interger



        # Return validated data

