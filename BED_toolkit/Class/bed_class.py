
'''
Tools to validate and manipulate bed files.
Created by Manuel Dominguez
'''

class Bed_tools:  
    '''
    Validation and target_rigion funtions 
    '''
    def __init__(self, BED): 
        '''
        Stores original bed data
        '''
        try:
            self.BED = self.validation(BED)
        except AssertionError:
            print("Do not pass validation")


    def validation(self, bed_data):
        """
        Validate if data taken from bed file is correct
        Bed file data is saved in a dict
        {'chr7': [127479365, 127480532], 'chr8': [127474697, 127475864]}
        """
        # Check if chromosomes values are string
        assert all(isinstance(key, str) for key in bed_data.keys()),"The key of the dict are not string"

        # Check if Start and End  are interger
        count_lines = 0
        for l1 in bed_data.values():
            for l2 in l1:
                count_lines +=1
                for e in l2:
                    assert isinstance(e, int), f"Values of the dictionnary aren't lists of integers. Assert found in line number  '{count_lines}' of the bed file."
            
        # Check Start is before End
        count_lines = 0
        for l1 in bed_data.values():
            for l2 in l1:
                count_lines +=1
                assert l2[0]<l2[1], f"START > END position. Assert found in line number  '{count_lines }' of the bed file."
            
        return bed_data


    def targe_region(self, bed,chro,position):
        """
        Tool 1: Look is position is covered by the Bed file input.
        """
        for key,value in bed.items():
            if key == chro:
                for values in value:
                    if int(position) in range(values[0], values[1]):
                        
                        output = "Your position is covered by this bed file"
                        return (output, key,values)
                        
                return "Your position is not coveraged by this bed file"





