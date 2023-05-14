import json
toto = {
    "name": "toto",
    "id": 1,
    "check_command": "toto" 
}

class Host:
    def __init__(self, hName, hAlias, hAddress):
        self.name = hName
        self.alias = hAlias
        self.address = hAddress


myHost = Host("toto", "titi", "localhost")
print(json.dumps(toto))

class HostEncoder(json.JSONEncoder):
    def default(self, obj):
        return {"name": obj.name, "alias": obj.alias, "address": obj.address}

print(json.dumps(myHost, cls=HostEncoder))