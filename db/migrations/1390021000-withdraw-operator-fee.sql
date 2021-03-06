ALTER TABLE currency
  ADD column withdraw_operator_fee bigint NOT NULL default 0;
  
CREATE OR REPLACE FUNCTION create_withdraw_request (
    aid int,
    method varchar,
    amnt bigint
) RETURNS int AS $$
DECLARE
    hid int;
    fee_network bigint;
    fee_operator bigint;
    total bigint;
BEGIN
    
    SELECT withdraw_fee, withdraw_operator_fee INTO fee_network, fee_operator FROM currency WHERE currency_id = method;
    total = amount + fee_network + fee_operator;
    
    INSERT INTO hold (account_id, total)
    VALUES (aid, amnt);

    hid := currval('hold_hold_id_seq');

    INSERT INTO withdraw_request(method, hold_id, account_id, amount)
    VALUES (method, hid, aid, amnt);

    RETURN currval('withdraw_request_request_id_seq');
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION confirm_withdraw(rid integer)
  RETURNS integer AS
$BODY$
DECLARE
        aid int;
        hmnt bigint;
        itid int;
        hid int;
        cid currency_id;
        fee_operator bigint;
BEGIN
    SELECT h.account_id, h.amount, h.hold_id, a.currency_id INTO aid, hmnt, hid, cid
    FROM withdraw_request wr
    INNER JOIN hold h ON wr.hold_id = h.hold_id
    INNER JOIN account a ON h.account_id = a.account_id
    WHERE wr.request_id = rid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'request/hold not found';
    END IF;

    UPDATE withdraw_request
    SET
        hold_id = NULL,
        completed_at = current_timestamp,
        state = 'completed'
    WHERE request_id = rid;

    DELETE from hold WHERE hold_id = hid;

    fee_operator := (SELECT withdraw_operator_fee from currency WHERE currency_id = cid);
    
    -- The accounts may be the same in the case of bridging
    IF aid <> special_account('edge', cid) THEN
        INSERT INTO transaction (debit_account_id, credit_account_id, amount, type, details)
        VALUES (aid, special_account('edge', cid), hmnt - fee_operator, 'Withdraw',
            (SELECT row_to_json(v) FROM (
                SELECT
                    rid request_id
            ) v)
        )
        RETURNING transaction_id
        INTO itid;
    END IF;

    IF fee_operator > 0 THEN
        INSERT INTO transaction (debit_account_id, credit_account_id, amount, type, details)
        VALUES (aid, special_account('fee', cid), fee_operator, 'WithdrawFee',
            (SELECT row_to_json(v) FROM (
                SELECT
                    rid request_id
            ) v)
        );
    END IF;

    RETURN itid;
END; $BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
