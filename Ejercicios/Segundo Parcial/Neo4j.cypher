1) 
CREATE (e:Estudiante {apellido:"Sosa", nombre:"Ramiro", edad:20,dni:33999888})
CREATE (m:Materia {codigo:"Física", descripcion:"F190", dia_cursado:"Miércoles"})
CREATE (p:Profesor {apellido:"Gomez", nombre:"Rolando", antiguedad:20, edad:55})
MATCH (e)-[:CURSAN]->(m)
MATCH (p)-[:DICTAN]->(m)

2)
MERGE (e:Estudiante)
WHERE e.edad > 21
RETURN e

3) Busca en el grafo todos los patrones en los que un nodo Estudiante está 
conectado mediante una relación CURSA (con esa dirección) a un nodo Materia, 
y devuelve ambos nodos (el estudiante s y la materia m) de cada coincidencia. 
En definitiva, retorna todos los estudiantes junto con las materias que cursan. 
Los estudiantes que no cursan ninguna materia no aparecen en el resultado, y si 
un estudiante cursa varias materias, aparece una vez por cada una.
