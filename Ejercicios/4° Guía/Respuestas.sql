-- 1)
CREATE OR REPLACE PROCEDURE ALTA_JOB 
(
  P_FUNCTION IN JOB.FUNCTION%TYPE 
) AS 
    v_job_id job.job_id%TYPE;
    
BEGIN
    SELECT MAX(job_id) + 1
    INTO v_job_id
    FROM job;
    
    INSERT
    INTO job (job_id, function)
    VALUES (v_job_id, UPPER(P_FUNCTION));
    
    COMMIT;
    
    dbms_output.put_line('¡Se insertó el cargo '||UPPER(p_function)||' con éxito! (ID: '||v_job_id||').');
EXCEPTION
    -- No usamos la excepción DUP_VAL_ON_INDEX, porque al sumar 1 al id máximo, nunca se van a repetir las PK.
    WHEN OTHERS THEN
        ROLLBACK;
        dbms_output.put_line('ERROR INESPERADO ('||SQLCODE||') :'||SQLERRM);
END ALTA_JOB;

-- 2)
CREATE OR REPLACE PROCEDURE UPD_JOB 
(
  PI_JOB_ID IN JOB.JOB_ID%TYPE
, PI_FUNCTION IN JOB.FUNCTION%TYPE 
) AS 
BEGIN
  UPDATE job
  SET function = UPPER(pi_function)
  WHERE job_id = pi_job_id;
  
  IF SQL%ROWCOUNT = 0 THEN
    ROLLBACK;
    dbms_output.put_line('No existe un JOB con el ID '||pi_job_id||', por lo que no se aplicó ninguna modificación.');
  ELSE
    dbms_output.put_line('Se modificó la función al JOB con ID '||pi_job_id||' a '||pi_function||' correctamente.');
    COMMIT;
  END IF;

EXCEPTION 
    WHEN OTHERS THEN
        dbms_output.put_line('ERROR INESPERADO ('||SQLCODE||'): '||SQLERRM);
END UPD_JOB;

-- 3)
CREATE OR REPLACE PROCEDURE LISTA_EMP 
(
  PI_DEPARTMENT_ID IN DEPARTMENT.DEPARTMENT_ID%TYPE 
) AS
    CURSOR c_employee IS
        SELECT first_name, last_name
        FROM employee
        WHERE department_id = pi_department_id;
    
    v_cont NUMBER := 0;
    v_existe NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO v_existe
    FROM department
    WHERE department_id = pi_department_id;
    
    IF v_existe = 0 THEN
        dbms_output.put_line('ERROR: No existe un departamento con ID '||pi_department_id);
    ELSE 
      dbms_output.put_line('DEPARTAMENTO '||pi_department_id);
      FOR i IN c_employee LOOP
        v_cont := v_cont + 1;
        dbms_output.put_line(v_cont||'. '||i.last_name||', '||i.first_name);
      END LOOP;
      
      IF v_cont = 0 THEN 
        dbms_output.put_line('Aún no tiene empleados.');
        END IF;
    END IF;
    
EXCEPTION 
    WHEN VALUE_ERROR THEN
        dbms_output.put_line('ERROR: El valor ingresado como ID de departamento es inválido.');
    WHEN OTHERS THEN 
        dbms_output.put_line('ERROR INESPERADO ('||SQLCODE||'): '||SQLERRM);
END LISTA_EMP;

-- 4)
-- PROCEDIMIENTO
CREATE OR REPLACE PROCEDURE CONSULTA_PRECIO (
    P_product_id IN  price.product_id%TYPE,
    P_list_price OUT price.list_price%TYPE,
    P_min_price  OUT price.min_price%TYPE
) AS
BEGIN
    SELECT list_price, min_price
      INTO P_list_price, P_min_price
      FROM price
     WHERE product_id = P_product_id
       AND end_date IS NULL;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        dbms_output.put_line('El producto ' || P_product_id || ' no existe.');
    WHEN TOO_MANY_ROWS THEN
        dbms_output.put_line('El producto ' || P_product_id || ' tiene más de un precio vigente.');
    WHEN OTHERS THEN
        dbms_output.put_line('Error inesperado (' || SQLCODE || '): ' || SQLERRM);
END CONSULTA_PRECIO;

-- 5)
-- FUNCIÓN
CREATE OR REPLACE FUNCTION Q_CREDIT 
(
  PI_CUSTOMER_ID IN CUSTOMER.CUSTOMER_ID%TYPE 
) RETURN CUSTOMER.CREDIT_LIMIT%TYPE AS 

    v_credit_limit customer.credit_limit%TYPE;
    
BEGIN
    SELECT credit_limit
    INTO v_credit_limit
    FROM customer
    WHERE customer_id = pi_customer_id;
    
  RETURN v_credit_limit;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
        dbms_output.put_line('ERROR: No existe un cliente con ID '||pi_customer_id);
    WHEN VALUE_ERROR THEN
        RETURN NULL;
        dbms_output.put_line('ERROR: El valor ingresado como ID es inválido.');
    WHEN OTHERS THEN
        dbms_output.put_line('ERROR INESPERADO ('||SQLCODE||'): '||SQLERRM);
END Q_CREDIT;

-- BLOQUE ANÓNIMO
SET SERVEROUTPUT ON
DECLARE
    v_limite customer.credit_limit%TYPE;
BEGIN
    v_limite := Q_CREDIT(100);
    dbms_output.put_line('Límite de crédito: '||NVL(TO_CHAR(v_limite), 'Cliente inexistente'));
END;

-- 6)
CREATE OR REPLACE FUNCTION VALIDA_LOC 
(
  P_LOCATION_ID IN LOCATION.LOCATION_ID%TYPE 
) RETURN BOOLEAN AS 
    V_LOCATION_ID LOCATION.LOCATION_ID%TYPE;
BEGIN
    SELECT location_id
    INTO V_LOCATION_ID
    FROM location
    WHERE location_id = p_location_id;
    
    RETURN TRUE;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN FALSE;
    WHEN VALUE_ERROR THEN
        dbms_output.put_line('ERROR: El valor ingresado como LOCATION_ID es inválido.');
        RETURN FALSE;
    WHEN OTHERS THEN 
        dbms_output.put_line('ERROR INESPERADO ('||SQLCODE||'): '||SQLERRM);
        RETURN FALSE;
END VALIDA_LOC;

-- 7)
CREATE OR REPLACE PROCEDURE NEW_DEPT (
    P_DEPARTMENT_ID IN DEPARTMENT.DEPARTMENT_ID%TYPE,
    P_NAME          IN DEPARTMENT.NAME%TYPE,
    P_LOCATION_ID   IN DEPARTMENT.LOCATION_ID%TYPE
) AS
BEGIN
    IF NOT VALIDA_LOC(P_LOCATION_ID) THEN
        RAISE_APPLICATION_ERROR(-20001, 'ERROR: La localidad ' || P_LOCATION_ID ||' no existe, por lo que se rechaza la inserción del nuevo departamento.');
    END IF;

    INSERT INTO department (department_id, name, location_id)
    VALUES (P_DEPARTMENT_ID, P_NAME, P_LOCATION_ID);

    dbms_output.put_line('Se insertó el departamento ' || P_DEPARTMENT_ID || ' correctamente.');

EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20002, 'ERROR: Ya existe un departamento con ese ID (' || P_DEPARTMENT_ID || ').');
    WHEN OTHERS THEN
        RAISE;
END NEW_DEPT;

-- 8)
