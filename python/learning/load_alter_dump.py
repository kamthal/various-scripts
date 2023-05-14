import json
fh = open("/home/omercier/global/perso/various-scripts/python/learning/hosts.json", "r")
json_input = fh.read()
fh.close()
print(json_input)
print("#################################")
data = json.loads(json_input)
data[0]["templates"] = [2, 3, 18]
fh = open("/home/omercier/global/perso/various-scripts/python/learning/hosts_modified.json", "w")
fh.write((json.dumps(data)))
fh.close()