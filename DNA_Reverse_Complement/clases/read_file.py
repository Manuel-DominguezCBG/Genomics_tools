'''
Read txt files and do some cleaning
'''


class Read_file():
    def __init__(self, file_path): 
        self.file_path = file_path
        
    def load_data(self):
        '''
        Load data from file and do some cleaning
        '''
        with open(self.file_path) as f:
            sequence = " ".join(line.strip() for line in f)  
            # line.strip() removes ends of the lines.
            # But leaves a white space!
            sequence = sequence.replace(" ", "")
            return sequence




