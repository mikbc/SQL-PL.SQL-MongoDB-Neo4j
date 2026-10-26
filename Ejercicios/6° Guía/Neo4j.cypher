3)
a. MATCH(e:Estudiante) RETURN e

b. MATCH(m:Materia) RETURN m

c. MATCH(e:Estudiante {name: "Lucas"}) RETURN e

d. MATCH(e:Estudiante)-[:APROBO]->(m:Materia) RETURN DISTINCT e

e. MATCH(e:Estudiante)-[:APROBO]->(m:Materia {name:"Física"}) RETURN DISTINCT e

f. MATCH(e:Estudiante)-[:CURSA]->(m:Materia) RETURN DISTINCT e

g. MATCH (e:Estudiante)
   WHERE 
   EXIST {
     MATCH (e)-[:APROBO]->(m:MATERIA {name:"Física"})
   } OR EXISTS {
     MATCH (e)-[:CURSA]->(m:Materia,{name:"Laboratorio 2"}) 
   } RETURN e
