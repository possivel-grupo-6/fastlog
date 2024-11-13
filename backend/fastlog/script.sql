create database fastlog;
use fastlog;

CREATE TABLE buy (
    code INT PRIMARY KEY,
    price DECIMAL(10, 2),
    cpf VARCHAR(14),
    product VARCHAR(255),
    status VARCHAR(255)
);