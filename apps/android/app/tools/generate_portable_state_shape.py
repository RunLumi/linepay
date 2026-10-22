import json
import argparse
from pathlib import Path
parser=argparse.ArgumentParser(description="Generate explicit compiled v1 field validators; no runtime schema engine.")
parser.add_argument("--schema", type=Path, default=Path(__file__).resolve().parents[4]/"shared/contracts/portable-state/schema-v1.json")
parser.add_argument("--check", action="store_true")
args=parser.parse_args()
schema=json.loads(args.schema.read_text())
out=['package com.streamentry.linepay.android','', 'import com.google.gson.JsonElement','import com.google.gson.JsonObject','', '/** Closed, version-specific structural validators for the shared portable-state v1 contract. */','internal object PortableStateShape {']
def q(x):return json.dumps(x,ensure_ascii=False).replace('$','\\$')
def generate(s,var,path,indent='        '):
 known={'$ref','const','type','additionalProperties','required','properties','enum','anyOf','maxItems','minItems','items','uniqueItems','minLength','maxLength','pattern','minimum','maximum','contentEncoding','$schema','$id','title','$defs'}
 assert not set(s)-known,(s,set(s)-known)
 z=[]
 def emit(a):z.append(indent+a)
 if '$ref'in s: emit('validate'+s['$ref'].split('/')[-1][0].upper()+s['$ref'].split('/')[-1][1:]+'('+var+', '+path+')');return z
 if 'anyOf'in s:
  choices=s['anyOf'];assert len(choices)==2 and choices[1]=={'type':'null'}
  emit('if (!'+var+'.isJsonNull) {');z+=generate(choices[0],var,path,indent+'    ');emit('}');return z
 if 'const'in s: emit('require('+var+' == com.google.gson.JsonParser.parseString('+q(json.dumps(s['const']))+')) { '+path+' + " has an unsupported value." }')
 if 'enum'in s:
  allowed = 'canonicalTimeZones' if s is schema['$defs']['timeZone'] else 'setOf('+', '.join(map(q,s['enum']))+')'
  emit('require('+var+'.isJsonPrimitive && '+var+'.asJsonPrimitive.isString && '+var+'.asString in '+allowed+') { '+path+' + " has an unsupported value." }')
 t=s.get('type')
 if t==['string','integer']:
  emit('if ('+var+'.isJsonPrimitive && '+var+'.asJsonPrimitive.isString) text('+var+', '+path+', 0, '+str(s.get('maxLength',100000000))+') else integer('+var+', '+path+', null, null)')
  return z
 if t=='object':
  assert s['additionalProperties']==False and set(s['required'])==set(s['properties'])
  emit('fields('+var+', '+path+', setOf('+', '.join(map(q,s['required']))+'))')
  for key,prop in s['properties'].items():z+=generate(prop,var+'.asJsonObject.get('+q(key)+')',path+' + '+q('.'+key),indent)
 elif t=='array':
  emit('array('+var+', '+path+', '+str(s.get('minItems',0))+', '+str(s.get('maxItems',100000))+', '+str(s.get('uniqueItems',False)).lower()+')')
  emit(var+'.asJsonArray.forEach { item ->');z+=generate(s['items'],'item',path+' + "[]"',indent+'    ');emit('}')
 elif t=='string':
  emit('text('+var+', '+path+', '+str(s.get('minLength',0))+', '+str(s.get('maxLength',100000000))+')')
  if 'pattern'in s: emit('require(Regex('+q(s['pattern'])+').matches('+var+'.asString)) { '+path+' + " has invalid text." }')
 elif t=='integer':emit('integer('+var+', '+path+', '+(q(str(s['minimum'])) if 'minimum' in s else 'null')+', '+(q(str(s['maximum'])) if 'maximum' in s else 'null')+')')
 elif t=='number':
  emit('require('+var+'.isJsonPrimitive && '+var+'.asJsonPrimitive.isNumber && '+var+'.asBigDecimal >= java.math.BigDecimal('+q(str(s.get('minimum', '-1E100')))+') && '+var+'.asBigDecimal <= java.math.BigDecimal('+q(str(s.get('maximum', '1E100')))+')) { '+path+' + " must be a bounded number." }')
 elif t=='boolean':emit('require('+var+'.isJsonPrimitive && '+var+'.asJsonPrimitive.isBoolean) { '+path+' + " must be boolean." }')
 elif t is not None:raise ValueError(t)
 return z
for name,s in [('document',schema)]+list(schema['$defs'].items()):
 body=generate(s,'value','path')
 if name=='date': body += ['        require(runCatching { java.time.LocalDate.parse(value.asString) }.isSuccess) { path + ": invalid calendar date." }']
 if name=='timeZone': body += ['        require(value.asString in java.time.ZoneId.getAvailableZoneIds()) { path + ": portable v1 needs a supported IANA time zone." }']
 out+=['    fun validate'+name[0].upper()+name[1:]+'(value: JsonElement, path: String = '+q(name)+') {']+body+['    }','']
out += ['    private val canonicalTimeZones = setOf('+', '.join(map(q,schema['$defs']['timeZone']['enum']))+')', '']
out+=['''    private fun fields(value: JsonElement, path: String, expected: Set<String>) {
        require(value.isJsonObject && value.asJsonObject.keySet() == expected) { "$path has missing or unknown fields." }
    }
    private fun text(value: JsonElement, path: String, minimum: Int, maximum: Int) {
        require(value.isJsonPrimitive && value.asJsonPrimitive.isString && value.asString.length in minimum..maximum) { "$path must be bounded text." }
    }
    private fun integer(value: JsonElement, path: String, minimum: String?, maximum: String?) {
        require(value.isJsonPrimitive && value.asJsonPrimitive.isNumber && value.asString.matches(Regex("-?(?:0|[1-9][0-9]*)")) && value.asBigDecimal.let { number -> (minimum == null || number >= java.math.BigDecimal(minimum)) && (maximum == null || number <= java.math.BigDecimal(maximum)) }) { "$path must be a supported exact integer." }
    }
    private fun array(value: JsonElement, path: String, minimum: Int, maximum: Int, unique: Boolean) {
        require(value.isJsonArray && value.asJsonArray.size() in minimum..maximum) { "$path must be a bounded collection." }
        require(!unique || value.asJsonArray.toList().toSet().size == value.asJsonArray.size()) { "$path contains duplicate values." }
    }
}''']
target=Path(__file__).resolve().parents[1]/"src/main/kotlin/com/streamentry/linepay/android/PortableStateShape.kt"
result='\n'.join(out)+'\n'
if args.check:
    if target.read_text()!=result:
        raise SystemExit("Portable v1 field validators differ from the canonical schema; regenerate and review.")
    print("Portable v1 compiled field validators match the canonical schema.")
else:
    target.write_text(result)
