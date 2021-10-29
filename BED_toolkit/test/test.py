import pytest

from ..Class.bed_class import Bed_tools
from ..Class.read_bed_file import Read_file

def test_load_data():
    ''' 
    Check if the dict created is exactly what I expect
    from the test_bed_file I have created
    This test_bed_file looks like this
    # browser position chr7:127471196-127495720
    # browser hide all
    track name="ItemRGBDemo" description="Item RGB demonstration" visibility=2 itemRgb="On"
    chr1    1    2    Pos1    0    +    127471196    127472363    255,0,0
    chr1    3    4    Pos2    0    +    127472363    127473530    255,0,0
    chr1    5    6    Pos3    0    +    127473530    127474697    255,0,0
    chr1    7    8    Pos4    0    +    127474697    127475864    255,0,0
    chr20    1    2    Neg1    0    -    127475864    127477031    0,0,255
    chr20    3    4    Neg2    0    -    127477031    127478198    0,0,255
    chrX    1    2    Neg3    0    -    127478198    127479365    0,0,255
    chrX    3    4    Pos5    0    +    127479365    127480532    255,0,0
    chrX    5    6    Neg4    0    -    127480532    127481699    0,0,255
    '''
    BED = Read_file("./file2test1.bed")
    assert BED.load_data() == {'chr1': [[1, 2], [3, 4], [5, 6], [7, 8]], 'chr20': [[1, 2], [3, 4]], 'chrX': [[1, 2], [3, 4], [5, 6]]}, "Dict created doesn´t match"

def test_validation1():
    ''' 
    Assert a ValueError due to one position is not a int
    chr1    p    2    Pos1    0    +    127471196    127472363    255,0,0
    '''
   
    BED = Read_file("./file2test2.bed")
    BED.load_data() == "Don't pass validation. End or start position are not interger chr1 p 2"

def test_validation2():
    ''' 
    Start is not before end
    chr1    1    2    Pos1    0    +    127471196    127472363    255,0,0
    chr1    10   3     Pos1    0    +    127471196    127472363    255,0,0
    '''
    BED = Read_file("./file2test3.bed")
    BED.load_data() == "START > END position. Assert found in line number  1 of the bed file."

def test_validation3():
    '''
    The key of the dict are not string
    chr1    1    2    Pos1    0    +    127471196    127472363    255,0,0
    chr1    10   3     Pos1    0    +    127471196    127472363    255,0,0
    chr1    1    2    Pos1    0    +    127471196    127472363    255,0,0
    3    10   3     Pos1    0    +    127471196    127472363    255,0,0
    '''
    BED = Read_file("./file2test4.bed")
    BED.load_data() == "The key of the dict are not string"

def test_target_region_position_covered():
    BED = Read_file("./file2test5.bed")
    data_loaded = BED.load_data()
    bed_data = Bed_tools(data_loaded)
    user_input2 =  "chrX:55"
    chro = user_input2.split(":")[0]
    position = user_input2.split(":")[1]    
    assert bed_data.targe_region(data_loaded, chro, position) == ('Your position is covered by this bed file', 'chrX', [50, 100])

def test_target_region_position_NO_covered():
    BED = Read_file("./file2test5.bed")
    data_loaded = BED.load_data()
    bed_data = Bed_tools(data_loaded)
    user_input2 =  "chrX:110"
    chro = user_input2.split(":")[0]
    position = user_input2.split(":")[1]    
    assert bed_data.targe_region(data_loaded, chro, position) == "Your position is not coveraged by this bed file"

