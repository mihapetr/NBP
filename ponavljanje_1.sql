-- creating a table
create table tablica (
    atribut_kljuc int,
    atribut_1 character varying(10),
    atribut_2 int
);

-- altering primary key constraint
alter table tablica
    add constraint pkey_constraint
    primary key (atribut_kljuc);

-- altering foreign key
alter table tablica
    add constraint fkey_cons
    foreign key (atribut_2) references referenca;

-- inserting into table
insert into tablica values (123, 'nesto', 15), (124, 'nesto dr', 16);

-- changing lenght of id in referenca
drop table referenca;
create table referenca (
    id int primary key,
    ime character(10) not null
);

-- finishing inserts for testing
insert into referenca values (15, 'def'), (16, 'ghi');

-- some (cartesian) selects:
select * from referenca;
select * from tablica;
select atribut_1, ime from tablica, referenca where atribut_2 = id; -- projekcija

-- left join
select * from tablica left join referenca on atribut_1 = ime;

-- built in funkcije (sum)
select dobavljac_id, sum(pakiranja_naruceno) from proizvodi
    group by dobavljac_id
    order by dobavljac_id asc;

-- podupiti
select * from proizvodi where kategorija_id = (
    select kategorija_id from kategorije where kategorija_naziv = 'Pića'
    );

-- aliasi
select proizvod_naziv, pakiranja_u_zalihi from proizvodi p1
    where p1.pakiranja_u_zalihi = (
        select max(pakiranja_u_zalihi) from proizvodi
        );

-- IN
select proizvod_naziv, dobavljac_id from proizvodi
    where dobavljac_id in (
        select dobavljac_id from dobavljaci where drzava = 'Germany'
        );

-- exists
select tvrtka_naziv, regija from dobavljaci d1 where exists(
    /*
    ako je tablica koj vraća podupit neprazna, onda je
    uvjet zadovoljen i select će se obabviti
    */
    );

-- views / pogledi
-- ovdje funkcionira replace
create or replace view francuzizacija as
    select tvrtka_naziv, adresa, drzava from dobavljaci
    where drzava = 'France';
select * from francuzizacija;

-- promjena talice kroz dvogled hehe (pogled)
update francuzizacija set tvrtka_naziv = 'Gay paturage hehe'
    where tvrtka_naziv = 'Gai pâturage';

/*
insert into dobavljaci
    (..) neki podupit koji vraća tablicu
*/

-- transakcija
/*
- nakon naredbe rollback work će se promjene resetirati
- da je umjesto te naredbe pozvana naredba commit work, bi promjene
bile spremljene zauvijek
*/
begin work;
update francuzizacija set adresa = 'Nigdje' where true;
select * from francuzizacija;
rollback work;
select * from francuzizacija;