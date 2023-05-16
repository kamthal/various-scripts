import json
import pathlib


fh = open(
    str(pathlib.Path(__file__).parent.resolve()) + "/source_data/host_groups.json",
    "r"
    )
json_input = fh.read()
fh.close()
print(json_input)