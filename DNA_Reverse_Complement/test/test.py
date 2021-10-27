import pytest

from ..clases.sequence import Sequence
from ..clases.read_file import Read_file

def test_reverse():
    sequence = Sequence("ACGT")
    assert sequence.reverse() == "TGCA", "Reverse sequence does´t match "

def test_reverse_argument():
    sequence = Sequence("ACGT")
    assert sequence.reverse("GGTTA") == "ATTGG", "Reverse sequence does´t match "

def test_complement():
    sequence = Sequence("ACGT")
    assert sequence.complement() == "TGCA", "Reverse sequence does´t match "

def test_complement_argument():
    sequence = Sequence("ACGT")
    assert sequence.complement("AACC") == "TTGG", "Reverse sequence does´t match "

def test_validation():
    sequence = Sequence("aatt")
    assert sequence.validation("aatt") == "AATT", "Upper convertion didnt work"

def test_type_validation():
    with pytest.raises(AssertionError):
        
        sequence = Sequence("ATGC")
        sequence.validation(123)

def test_nucleotipe_validation():
    with pytest.raises(AssertionError):
        
        sequence = Sequence("ATGC")
        sequence.validation("ATGCKILLO")

def test_reverse_complement():
    sequence = Sequence("AACC")
    assert sequence.reverse_and_complement() == "GGTT", "Reverse sequence does´t match "

def test_reverse_complement_argument():
    sequence = Sequence("AACC")
    assert sequence.reverse_and_complement("GTA") == "TAC", "Reverse sequence does´t match "

def test_load_data():
    sequence = Read_file("/Users/monkiky/Desktop/DOPS programming/DOP11/files/DNA.txt")
    # Check white spaces
    assert sequence.load_data() == "TATAGATAGATAGATAGATAGATAGATAGATAGATACCCCCCCCCCCC" , "White spaces found in the sequence"

def test_gc_percentage():
    sequence = Sequence("AAGC")
    assert sequence.gc_percentage() == 2, "gc_percentage function is not working correctly"



