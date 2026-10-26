-------------------------------------------------------- SPEC -----------------------------------------------------------
create or replace PACKAGE PA_VENTAS AS 

  PROCEDURE P_ALTA_ITEM (
    P_PRODUCT_ID IN ITEM.PRODUCT_ID%TYPE,
    P_ORDER_ID IN ITEM.ORDER_ID%TYPE,
    P_QUANTITY IN ITEM.QUANTITY%TYPE,
    P_ITEM_ID OUT ITEM.ITEM_ID%TYPE
  );
  
  PROCEDURE P_ALTA_ITEM (
    P_DESCRIPTION IN PRODUCT.DESCRIPTION%TYPE,
    P_ORDER_ID IN ITEM.ORDER_ID%TYPE,
    P_QUANTITY IN ITEM.QUANTITY%TYPE,
    P_ITEM_ID OUT ITEM.ITEM_ID%TYPE
  );
  
  PROCEDURE P_LISTAR_VENTAS (
    P_PRODUCT_ID IN PRODUCT.PRODUCT_ID%TYPE
  );
  
  PROCEDURE P_LISTAR_VENTAS (
    P_DESCRIPTION IN PRODUCT.DESCRIPTION%TYPE
  );
  
  PROCEDURE P_LISTAR_VENTAS;
  
  
END PA_VENTAS;

-------------------------------------------------------- BODY -----------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY PA_VENTAS AS

  -- Nombres para los errores que lanza F_GET_ID
  e_prod_no_existe EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_prod_no_existe, -20001);
  e_prod_repetido  EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_prod_repetido, -20002);

 
  -- 2) FUNCIÓN PRIVADA (no está en la spec)
  FUNCTION F_GET_ID (
    P_DESCRIPTION IN PRODUCT.DESCRIPTION%TYPE
  ) RETURN PRODUCT.PRODUCT_ID%TYPE
  IS
    v_id PRODUCT.PRODUCT_ID%TYPE;
  BEGIN
    SELECT product_id
    INTO v_id
    FROM product
    WHERE description = P_DESCRIPTION;

    RETURN v_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20001,'ERROR: No existe un producto con la descripción '||P_DESCRIPTION||'.');
    WHEN TOO_MANY_ROWS THEN
        RAISE_APPLICATION_ERROR(-20002,'ERROR: Existe más de un producto con la descripción '||P_DESCRIPTION||'.');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003,'ERROR INESPERADO ('||SQLCODE||'): '||SQLERRM);
  END F_GET_ID;

  -- PRIVADO: muestra las ventas. NULL = todos los productos.
  -- Tiene nombre propio (NO sobrecargado) y lo usan las 3 versiones de listar.
  PROCEDURE P_MOSTRAR_VENTAS (
    P_PRODUCT_ID IN PRODUCT.PRODUCT_ID%TYPE
  ) AS
    CURSOR c_product IS
        SELECT product_id, description
        FROM product
        WHERE P_PRODUCT_ID IS NULL
           OR product_id = P_PRODUCT_ID
        ORDER BY product_id;

    CURSOR c_venta (p_prod PRODUCT.PRODUCT_ID%TYPE) IS
        SELECT O.order_id, O.order_date, I.quantity, I.actual_price
        FROM sales_order O,
             item I
        WHERE O.order_id = I.order_id
          AND I.product_id = p_prod
        ORDER BY O.order_date, O.order_id;

    v_cont NUMBER := 0;   -- ventas del producto actual
    v_cont_prod NUMBER := 0;   -- productos encontrados
  BEGIN
    FOR i IN c_product LOOP
        v_cont_prod := v_cont_prod + 1;
        v_cont := 0;

        dbms_output.put_line('Producto: '||i.description);
        dbms_output.put_line('Fecha        Cant   Precio');

        FOR j IN c_venta(i.product_id) LOOP
            dbms_output.put_line(TO_CHAR(j.order_date,'dd/mm/yyyy')||'   '||j.quantity||'   $'||j.actual_price);
            v_cont := v_cont + 1;
        END LOOP;

        IF v_cont = 0 THEN
            dbms_output.put_line('El producto aún no fue vendido.');
        ELSE
            dbms_output.put_line('Cantidad de ventas: '||v_cont);
        END IF;
        dbms_output.put_line('');
    END LOOP;

    -- Si el cursor de productos no devolvió nada
    IF v_cont_prod = 0 THEN
        IF P_PRODUCT_ID IS NULL THEN
            dbms_output.put_line('No hay productos cargados.');
        ELSE
            dbms_output.put_line('ERROR: No existe un producto con el ID '||P_PRODUCT_ID);
        END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
        dbms_output.put_line('ERROR INESPERADO ('||SQLCODE||'): '||SQLERRM);
  END P_MOSTRAR_VENTAS;

  -- 1) ALTA DE ÍTEM por id (hace el trabajo real)
  PROCEDURE P_ALTA_ITEM (
    P_PRODUCT_ID IN ITEM.PRODUCT_ID%TYPE,
    P_ORDER_ID   IN ITEM.ORDER_ID%TYPE,
    P_QUANTITY   IN ITEM.QUANTITY%TYPE,
    P_ITEM_ID    OUT ITEM.ITEM_ID%TYPE
  ) AS
    v_list_price PRICE.LIST_PRICE%TYPE;
    v_item_id    ITEM.ITEM_ID%TYPE;

    e_cantidad EXCEPTION;

    e_fk EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_fk, -2291);
    e_not_null EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_not_null, -1400);

  BEGIN
    P_ITEM_ID := NULL;

    IF P_QUANTITY IS NULL OR P_QUANTITY <= 0 THEN
        RAISE e_cantidad;
    END IF;

    SELECT list_price
    INTO v_list_price
    FROM price
    WHERE product_id = P_PRODUCT_ID
      AND end_date IS NULL;

    SELECT NVL(MAX(item_id),0)+1
    INTO v_item_id
    FROM item
    WHERE order_id = P_ORDER_ID;

    INSERT
    INTO item (order_id, item_id, product_id, actual_price, quantity, total)
    VALUES (P_ORDER_ID, v_item_id, P_PRODUCT_ID, v_list_price, P_QUANTITY, v_list_price*P_QUANTITY);

    P_ITEM_ID := v_item_id;   -- recién ahora, con el alta ya hecha
    dbms_output.put_line('El ítem '||P_ITEM_ID||' fue dado de alta exitosamente en la orden '||P_ORDER_ID);

  EXCEPTION
    WHEN e_cantidad THEN
        dbms_output.put_line('ERROR: La cantidad no puede ser NULL, menor o igual a cero.');
    WHEN NO_DATA_FOUND THEN
        dbms_output.put_line('ERROR: El producto '||P_PRODUCT_ID||' no existe o no tiene precio de lista vigente.');
    WHEN TOO_MANY_ROWS THEN
        dbms_output.put_line('ERROR: El producto '||P_PRODUCT_ID||' tiene más de un precio de lista vigente.');
    WHEN e_fk THEN
        dbms_output.put_line('ERROR: La orden '||P_ORDER_ID||' no existe.');
    WHEN e_not_null THEN
        dbms_output.put_line('ERROR: Falta un dato obligatorio.');
    WHEN DUP_VAL_ON_INDEX THEN
        dbms_output.put_line('ERROR: El ítem ya existe en la orden '||P_ORDER_ID);
    WHEN OTHERS THEN
        dbms_output.put_line('ERROR INESPERADO ('||SQLCODE||'): '||SQLERRM);
  END P_ALTA_ITEM;

  -- 1) ALTA DE ÍTEM por descripción (sobrecarga)
  PROCEDURE P_ALTA_ITEM (
    P_DESCRIPTION IN PRODUCT.DESCRIPTION%TYPE,
    P_ORDER_ID    IN ITEM.ORDER_ID%TYPE,
    P_QUANTITY    IN ITEM.QUANTITY%TYPE,
    P_ITEM_ID     OUT ITEM.ITEM_ID%TYPE
  ) AS
    v_product_id PRODUCT.PRODUCT_ID%TYPE;
  BEGIN
    P_ITEM_ID := NULL;
    v_product_id := F_GET_ID(P_DESCRIPTION);
    P_ALTA_ITEM(v_product_id, P_ORDER_ID, P_QUANTITY, P_ITEM_ID);
  EXCEPTION
    WHEN e_prod_no_existe THEN
        dbms_output.put_line('ERROR: No existe un producto con la descripción '||P_DESCRIPTION||'.');
    WHEN e_prod_repetido THEN
        dbms_output.put_line('ERROR: Existe más de un producto con la descripción '||P_DESCRIPTION||'.');
    WHEN OTHERS THEN
        dbms_output.put_line('ERROR INESPERADO ('||SQLCODE||'): '||SQLERRM);
  END P_ALTA_ITEM;

  -- 3) LISTAR VENTAS (3 versiones, las 3 delegan en P_MOSTRAR_VENTAS)
  PROCEDURE P_LISTAR_VENTAS (
    P_PRODUCT_ID IN PRODUCT.PRODUCT_ID%TYPE
  ) AS
  BEGIN
    P_MOSTRAR_VENTAS(P_PRODUCT_ID);
  END P_LISTAR_VENTAS;

  PROCEDURE P_LISTAR_VENTAS (
    P_DESCRIPTION IN PRODUCT.DESCRIPTION%TYPE
  ) AS
    v_product_id PRODUCT.PRODUCT_ID%TYPE;
  BEGIN
    v_product_id := F_GET_ID(P_DESCRIPTION);
    P_MOSTRAR_VENTAS(v_product_id);
  EXCEPTION
    WHEN e_prod_no_existe THEN
        dbms_output.put_line('ERROR: No existe un producto con la descripción '||P_DESCRIPTION||'.');
    WHEN e_prod_repetido THEN
        dbms_output.put_line('ERROR: Existe más de un producto con la descripción '||P_DESCRIPTION||'.');
    WHEN OTHERS THEN
        dbms_output.put_line('ERROR INESPERADO ('||SQLCODE||'): '||SQLERRM);
  END P_LISTAR_VENTAS;

  PROCEDURE P_LISTAR_VENTAS AS
  BEGIN
    P_MOSTRAR_VENTAS(NULL);
  END P_LISTAR_VENTAS;

END PA_VENTAS;
