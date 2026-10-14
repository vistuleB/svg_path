import json,re
from pathlib import Path
import xml.etree.ElementTree as ET
r=Path(__file__).resolve().parent
rows=[]
for f in sorted((r/'upstream/test/plugins').glob('*.svg.txt')):
 if f.name.startswith('convertPathData.'):continue
 text=f.read_text().strip(); ds=re.split(r'\s*===\s*',text)
 if len(ds)==2:text=ds[1]
 parts=re.split(r'\s*@@@\s*',text)
 def nodes(xml):
  result=[]
  def walk(e,ancestors):
   result.append(dict(tag=e.tag.split('}')[-1],attributes=dict(e.attrib),ancestors=ancestors))
   for child in e:walk(child,ancestors+[dict(e.attrib)])
  walk(ET.fromstring(xml),[])
  return result
 try: before,after=nodes(parts[0]),nodes(parts[1]);error=None
 except ET.ParseError as e:before=after=None;error=str(e)
 rows.append(dict(file=f.name,plugin=f.name.split('.')[0],original=parts[0],expected=parts[1],params=json.loads(parts[2]) if len(parts)>2 else {},inputs=before,outputs=after,xmlExtractionError=error))
(r/'extra-fixtures.json').write_text(json.dumps(rows,indent=2)+'\n')
print(len(rows),'additional fixtures inventoried')
