'''
DNA toolkit

'''

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
        
    def validation(self, sequence):
        """
        Validate a input DNA sequence
        Convert to uppercase
        Check for valid nucleotides 
        if invalid rise an exception
        """
        # Check if input is string
        assert isinstance(sequence, str),  "The sequence is not a string"
        # Convert to uppercase
        sequence = sequence.upper()

        # Check for valid nucleotides

        # Define valid nucleotide 
        valid_nucleotide = set("ATCG")

        # Check our seq againt this list
        if  set(sequence) <= valid_nucleotide:
            return sequence
        
        raise AssertionError('Invalid nucleotides.')
        # Return validated sequence

    def length(self):
        '''
        That returns the length of the original sequence
        '''
        return len(self.DNA)
    
    def complement(self,seq=None): 
        '''
        Return the complement of a seq given
        '''
        complement_dict = {"A": "T", "T": "A","G":"C","C":"G"}
        if seq is None:
            seq = self.DNA
        complement_seq = []
        for k in  seq: 
            complement_seq.append(complement_dict[k])
        return "".join(complement_seq)

    def reverse(self,seq = None):
        '''
        Reverse a given seq
        '''
        if seq is None:
            seq = self.DNA
        reverse_seq = seq[::-1]
        return reverse_seq
    
    def reverse_and_complement(self,seq = None):
        '''
        Do the reverse first and the then the complement
        calling the function reverse() and complement()
        '''
        if seq is None:
            seq = self.DNA
        first = self.reverse(seq)
        second = self.complement(first)
        return second

    def gc_percentage(self):
        '''
        Count the percentage of GC in the sequence
        '''
        gc_nucleotides = self.DNA.count('G') + self.DNA.count('C')
        total_seq = self.length()
        return total_seq/gc_nucleotides 



