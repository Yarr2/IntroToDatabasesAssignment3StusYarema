
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




