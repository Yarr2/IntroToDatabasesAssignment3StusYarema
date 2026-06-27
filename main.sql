
drop table if exists customers;

drop table if exists products;

drop table if exists orders;

drop table if exists order_items;

drop table if exists order_log;



create table customers (
    customer_id serial primary key,
    full_name varchar(100) not null,
    email varchar(100) unique not null,
    balance numeric(10,2) default 0
);

create table products (
    product_id serial primary key,
    product_name varchar(100) not null,
    price numeric(10,2) not null,
    stock_quantity int not null
);

create table orders (
    order_id serial primary key,
    customer_id int references customers(customer_id),
    order_date timestamp default current_timestamp,
    total_amount numeric(10,2) default 0
);

create table order_items (
    order_item_id serial primary key,
    order_id int references orders(order_id),
    product_id int references products(product_id),
    quantity int not null,
    price numeric(10,2) not null
);

create table order_log (
    log_id serial primary key,
    order_id int,
    customer_id int,
    action varchar(50),
    log_date timestamp default current_timestamp
);


create or replace function 
calculate_order_total (p_order_id int)
returns numeric(10,2)
language plpgsql
as $$
declare
	total_cost numeric(10,2);
begin
	select coalesce(sum(oi.quantity * oi.price), 0.00)
	into total_cost
	from order_items oi
	where oi.order_id = p_order_id;

	return total_cost;
end;
$$;

create or replace procedure
create_order(p_customer_id int)
language plpgsql
as $$
begin
	if p_customer_id in (select c.customer_id from customers c) then 
		insert into orders (customer_id) values (p_customer_id);
	else raise exception 'There is no customer with id %', p_customer_id;
	end if;
	commit;
end;
$$;

create or replace procedure
add_product_to_order(
    p_order_id int,
    p_product_id int,
    p_quantity int
)
language plpgsql
as $$
declare
	price numeric(10,2);
begin
	if p_order_id not in (select o.order_id from orders o) then
		raise exception 'There is no order with id %', p_order_id;
	end if;
	
	if p_quantity <= 0 then 
		raise exception 'Quantity should be positive, not %', p_quantity;
	end if;

	if p_quantity > (
		select coalesce(p.stock_quantity, 0) 
		from products p 
		where p.product_id == p_product_id) then
		raise exception 'Cannot give more product than are in stock';
	end if;

	select p.price
	into price
	from products p
	where p.product_id = p_product_id;

	update products p
	set p.stock_quantity = p.stock_quantity - p_quantity
	where p.product_id = p_product_id;
	
	insert into order_items (order_id, product_id, quantity, price)
	values (p_order_id, p_product_id, p_quantity, price);
end;
$$;

/* triggers */ 
create or replace function update_order_total()
returns trigger as $$
begin
    if (tg_op = 'DELETE') then
        update orders 
        set total_amount = calculate_order_total(old.order_id)
        where order_id = old.order_id;
        return old;
    else
        update orders 
        set total_amount = calculate_order_total(new.order_id)
        where order_id = new.order_id;
       	return new;
    end if;
end;
$$ language plpgsql;


create trigger trg_update_order_total
after insert or update or delete on order_items
for each row
execute function update_order_total();



create or replace function log_new_order()
returns trigger as $$
begin
    insert into order_log (order_id, customer_id, action) /* log_date is set automatically to current time*/
    values (new.order_id, new.customer_id, 'ORDER_CREATED');
    
    return new;
end;
$$ language plpgsql;

create trigger trg_log_new_order
after insert on orders
for each row
execute function log_new_order();




