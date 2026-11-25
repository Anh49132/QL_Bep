\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE
    session_id uuid := gen_random_uuid();
    order_id uuid := gen_random_uuid();
    old_name text;
    old_price numeric;
BEGIN
    IF (SELECT count(*) FROM "MenuItems" WHERE "Id" BETWEEN 1 AND 10) <> 10
        OR (SELECT count(*) FROM "RestaurantTables" WHERE "Number" BETWEEN 1 AND 5) <> 5 THEN
        RAISE EXCEPTION 'Missing seed rows';
    END IF;
    SELECT "Name", "Price" INTO old_name, old_price FROM "MenuItems" WHERE "Id" = 1;
    INSERT INTO "TableSessions" ("Id", "TableNumber", "CustomerCode", "StartedAt")
    VALUES (session_id, 1, 'WEEK2-CHECK', now());
    INSERT INTO "Orders" ("Id", "Code", "TableSessionId", "TableNumber", "CustomerCode", "CreatedAt", "Status", "Notes", "Total")
    VALUES (order_id, order_id::text::varchar(32), session_id, 1, 'WEEK2-CHECK', now(), 'Pending', 'Check snapshot', old_price * 2);
    INSERT INTO "OrderItems" ("OrderId", "MenuItemId", "MenuItemName", "UnitPrice", "Quantity", "Notes")
    VALUES (order_id, 1, old_name, old_price, 2, 'Check quantity');
    UPDATE "MenuItems" SET "Name" = 'Changed menu name', "Price" = 12345.67 WHERE "Id" = 1;
    IF NOT EXISTS (SELECT 1 FROM "OrderItems" WHERE "OrderId" = order_id AND "MenuItemName" = old_name AND "UnitPrice" = old_price) THEN
        RAISE EXCEPTION 'Order snapshot changed';
    END IF;
    IF (SELECT "Price" FROM "MenuItems" WHERE "Id" = 1) <> 12345.67 THEN
        RAISE EXCEPTION 'Decimal precision lost';
    END IF;
    BEGIN
        UPDATE "OrderItems" SET "Quantity" = 0 WHERE "OrderId" = order_id;
        RAISE EXCEPTION 'Zero quantity accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        UPDATE "OrderItems" SET "UnitPrice" = -1 WHERE "OrderId" = order_id;
        RAISE EXCEPTION 'Negative price accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        UPDATE "Orders" SET "TableNumber" = 2 WHERE "Id" = order_id;
        RAISE EXCEPTION 'Mismatched session/table accepted';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;
    BEGIN
        UPDATE "Orders" SET "Status" = 'Invalid' WHERE "Id" = order_id;
        RAISE EXCEPTION 'Invalid status accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
END $$;
ROLLBACK;
SELECT 'PASS: seed, decimal, historical snapshot and database constraints';
