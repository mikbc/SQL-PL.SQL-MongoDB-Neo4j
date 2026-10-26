1)
CREATE(e:Estudiante {apellido:"Sosa", nombre:"Ramiro", edad:20, dni:33999888})
CREATE(m:Materia {codigo:"F190", descripcion:"Física" , dia:"Miércoles"})
CREATE(p:Profesor {apellido:"Gomez", nombre: "Rolando", antiguedad:20, edad:55})
CREATE (e)-[:CURSA]->(m)
CREATE (p)-[:DICTA]->(m)

2) 
MATCH(e:Estudiante)
WHERE e.edad > 21
RETURN e

3) La siguiente operación muestra a todos los Estudiantes que esten CURSANDO una 
   materia y a aquellas Materias. Es decir, aquellos nodos Estudiante y Materia
   que tengan una relación entre si. Por este motivo, no aparecerían aquellos
   Estudiantes que no están cursando una materia, ni las Materias que no tienen
   estudiantes cursandola.  
   MATCH(s:Estudiante)-[:CURSA]->(m:Materia)
   RETURN s, m
