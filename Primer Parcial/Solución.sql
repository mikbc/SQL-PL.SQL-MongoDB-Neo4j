-- 1)
SELECT C.name, E.first_name||', '||E.last_name AS vendedor
FROM customer C,
    employee E
WHERE C.salesperson_id = E.employee_id
    AND 5 > (SELECT COUNT(*)
             FROM sales_order S
             WHERE S.customer_id = C.customer_id)
ORDER BY C.name;

/* Comprobación:
   SELECT C.name, COUNT(S.order_id)
   FROM sales_order S,
       customer C
   WHERE S.customer_id = C.customer_id
   GROUP BY C.name
   HAVING 5 > COUNT(S.order_id); */

-- 2)
create or replace FUNCTION F_1PARCIAL 
(
  P_NAME IN CUSTOMER.NAME%TYPE 
) RETURN CUSTOMER.CUSTOMER_ID%TYPE AS 
    V_CUSTOMER_ID CUSTOMER.CUSTOMER_ID%TYPE;
BEGIN
    SELECT customer_id
    INTO V_CUSTOMER_ID
    FROM customer
    WHERE name = UPPER(P_NAME);
    
  RETURN V_CUSTOMER_ID;
  
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20001, 'ERROR: No se encontró un cliente con el nombre '||P_NAME||'.');
    WHEN TOO_MANY_ROWS THEN
        RAISE_APPLICATION_ERROR(-20002, 'ERROR: Existe más de un cliente con el nombre '||P_NAME||'.');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003, 'ERROR INESPERADO ('||SQLCODE||'): '||SQLERRM);
END F_1PARCIAL;

-- 3)
create or replace PROCEDURE PR_1PARCIAL (
    PI_CUSTOMER_ID     IN CUSTOMER.CUSTOMER_ID%TYPE,
    PI_CUSTOMER_NAME   IN CUSTOMER.NAME%TYPE,
    PI_ADDRESS         IN CUSTOMER.ADDRESS%TYPE,
    PI_CITY            IN CUSTOMER.CITY%TYPE,
    PI_ZIP_CODE        IN CUSTOMER.ZIP_CODE%TYPE,
    PI_SALESPERSON_ID  IN CUSTOMER.SALESPERSON_ID%TYPE
) AS
    v_customer_id CUSTOMER.CUSTOMER_ID%TYPE;
    v_existe      BOOLEAN := TRUE;

    -- Excepciones de VALIDA_CLIENTE
    e_no_existe   EXCEPTION;
    e_repetido    EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_no_existe, -20001);
    PRAGMA EXCEPTION_INIT(e_repetido,  -20002);

    -- Errores de constraints
    e_fk          EXCEPTION;   -- padre no existe
    e_not_null    EXCEPTION;
    e_check       EXCEPTION;
    e_demasiado   EXCEPTION;   -- valor más largo que la columna
    PRAGMA EXCEPTION_INIT(e_fk,        -2291);
    PRAGMA EXCEPTION_INIT(e_not_null,  -1400);
    PRAGMA EXCEPTION_INIT(e_check,     -2290);
    PRAGMA EXCEPTION_INIT(e_demasiado, -12899);
BEGIN
    -- 1) Ver si ya hay un cliente con ese nombre
    BEGIN
        v_customer_id := F_1PARCIAL(PI_CUSTOMER_NAME);
    EXCEPTION
        WHEN e_no_existe THEN
            v_existe := FALSE;       -- es lo que queremos: se puede dar de alta
    END;

    -- 2) Insertar solo si NO existe
    IF v_existe THEN
        dbms_output.put_line('No se dio de alta: ya existe el cliente ' ||
                             PI_CUSTOMER_NAME || ' (id ' || v_customer_id || ').');
    ELSE
        INSERT INTO customer (customer_id, name, address, city, zip_code, salesperson_id)
        VALUES (PI_CUSTOMER_ID, PI_CUSTOMER_NAME, PI_ADDRESS, PI_CITY, PI_ZIP_CODE, PI_SALESPERSON_ID);

        dbms_output.put_line('Cliente ' || PI_CUSTOMER_ID || ' dado de alta correctamente.');
    END IF;

EXCEPTION
    WHEN e_repetido THEN
        dbms_output.put_line('No se dio de alta: existe más de un cliente con el nombre ' || PI_CUSTOMER_NAME);
    WHEN DUP_VAL_ON_INDEX THEN
        dbms_output.put_line('No se dio de alta: ya existe un cliente con el id ' || PI_CUSTOMER_ID);
    WHEN e_fk THEN
        dbms_output.put_line('No se dio de alta: el vendedor ' || PI_SALESPERSON_ID || ' no existe.');
    WHEN e_not_null THEN
        dbms_output.put_line('No se dio de alta: falta un dato obligatorio (NOT NULL).');
    WHEN e_check THEN
        dbms_output.put_line('No se dio de alta: un valor viola una restricción CHECK.');
    WHEN e_demasiado THEN
        dbms_output.put_line('No se dio de alta: un valor es demasiado largo para su columna.');
    WHEN OTHERS THEN
        dbms_output.put_line('No se dio de alta. Error inesperado (' || SQLCODE || '): ' || SQLERRM);
END PR_1PARCIAL;

--4)
SET SERVEROUTPUT ON

DECLARE
    v_customer_id customer.customer_id%TYPE;
    v_name        customer.name%TYPE;

    CURSOR c_order IS
        SELECT order_id, order_date, total
          FROM sales_order
         WHERE customer_id = v_customer_id
         ORDER BY order_date;

    CURSOR c_item (p_order sales_order.order_id%TYPE) IS
        SELECT i.item_id, p.description, i.actual_price, i.quantity, i.total
          FROM item i
          JOIN product p ON p.product_id = i.product_id
         WHERE i.order_id = p_order
         ORDER BY i.item_id;

    v_cont_items  NUMBER := 0;
    v_cont_ventas NUMBER := 0;
BEGIN
    v_customer_id := &customer_id;

    SELECT name
      INTO v_name
      FROM customer
     WHERE customer_id = v_customer_id;   -- NO_DATA_FOUND si no existe

    dbms_output.put_line('Cliente: ' || v_name);
    dbms_output.put_line('');

    FOR i IN c_order LOOP
        v_cont_ventas := v_cont_ventas + 1;
        v_cont_items  := 0;

        dbms_output.put_line('Id   Fecha        Total');
        dbms_output.put_line(i.order_id || '   ' || TO_CHAR(i.order_date, 'DD/MM/YYYY') || '   $' || i.total);
        dbms_output.put_line('     Ítem_id  Producto  Precio  Cant  Total');

        FOR j IN c_item(i.order_id) LOOP
            dbms_output.put_line('     ' || j.item_id || '   ' || j.description || '   $' ||
                                 j.actual_price || '   ' || j.quantity || '   $' || j.total);
            v_cont_items := v_cont_items + 1;
        END LOOP;

        dbms_output.put_line('   Cantidad de items: ' || v_cont_items);
        dbms_output.put_line('');
    END LOOP;

    IF v_cont_ventas = 0 THEN
        dbms_output.put_line('Este cliente aún no cuenta con órdenes.');
    ELSE
        dbms_output.put_line('Total ventas: ' || v_cont_ventas);
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        dbms_output.put_line('ERROR: El cliente con el ID ' || v_customer_id || ' no existe.');
    WHEN OTHERS THEN
        dbms_output.put_line('ERROR INESPERADO (' || SQLCODE || '): ' || SQLERRM);
END;
