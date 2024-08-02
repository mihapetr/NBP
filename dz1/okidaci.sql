-- RUTINE

-- testna funkcija
-- replace paradigma korisna za debugging pristup čestog mijenjanja
create or replace function foo (argument int) returns int as $$
    begin
        return argument;
    end;
    $$ language plpgsql;

-- poziv funkcije
select * from foo(45);

-- varijable
create or replace function f2 (ulaz studenti.jmbag%type) returns studenti.jmbag%type as $$
    declare -- declare blok ide prije begin
        var             char(10); -- sami deklariramo tip
        varijabla1      studenti.jmbag%type; -- kopiramo tip jmbag-a
        varijabla2      varijabla1%type; -- kopiramo tip druge varijable
    begin
        return true;
    end;
    $$ language plpgsql;

-- if, else, case
create or replace function f3 () returns bool as $$
    declare -- tipove pošemo čitko u isti stupac
            -- varijable bi trebale počinjati s _
        _uvjet1      bool;
        _uvjet2      bool;
        _varijabla   int;
    begin
        if _uvjet1 and _uvjet2 then
            -- do something
        elsif _uvjet2 then
            -- do something
        else
            -- do something
        end if;

        case _varijabla
        when 1 then
            -- naredbe
        when 2, 3 then
            -- naredbe
        else
            -- naredbe
        end case;
    end;
    $$ language plpgsql;

-- komkatenacija stringova se radi s pipe operatorom ||
-- _str1 || _str2

-- procedure
-- ne vraćaju podatke, nemaju return
create or replace procedure p1 (_proizvod_id proizvodi.proizvod_id%type) as $$
    declare
        _proizvod_naziv     proizvodi.proizvod_naziv%type;
        _record             record;
    begin
        -- select u proceduri
        -- može u više varijabli odjednom
        select proizvod_naziv, proizvod_id into _proizvod_naziv, _proizvod_id
            from proizvodi where proizvod_id = _proizvod_id;

        -- može se selectati i u varijablu tipa record
        -- ona se dinamički prilagođava velčini podatka
        select proizvod_naziv, proizvod_id into _record
            from proizvodi where proizvod_id = _proizvod_id;

        -- kasnije u _record varijabli njene komponente imaju imena iz selecta
        -- u ovom slućaju proizvod_naziv i proizvod_id
        -- dohvaćaju se s _record.proizvod_naziv npr.

        -- privremene tablice
        create temp table if not exists rezultat_p1 as
            select proizvod_naziv, proizvod_id from proizvodi where
                proizvod_id = _proizvod_id;

        insert into rezultat_p1 values (_proizvod_naziv, _proizvod_id);
    end;
    $$ language plpgsql;

-- procedure se ne mogu pozivati kao funkcije
drop table rezultat_p1;
-- cast operator
call p1 (cast(2 as smallint));
select * from rezultat_p1;

create or replace function petlje () as $$
    declare
        uvjet       bool;
    begin
        -- obični loop
        loop
            -- naredbe
        exit when uvjet;
        continue when uvjet; -- preskaće iteraciju
            -- naredbe
        end loop;

        -- while loop
        while uvjet loop
        -- naredbe
        end loop;

        -- for petlja
        -- moguće razne varijacije, ovo je osnovna sintaksa
        for i in 1..10 loop
            -- naredbe
            end loop;

        -- kada select vraća više redaaka onda se ponaša kao skup
        -- funkcionira i s record varijablom
        for _v1, _v2 in
                select proizvod_id, proizvod_naziv
                from proizvodi
            loop
                -- tipkamo nešto korisno
                -- možemo koristiti _v1 i _v2
            end loop;

    end;
    $$ language plpgsql;

-- vraćanje više redaka / vrijednosti iz funkcije
create or replace function multiple() returns table (id smallint, naziv varchar(40)) as $$
    begin
        return query
        select proizvod_id, proizvod_naziv from proizvodi;
        -- nakon return query naredbe se ne zaustavlja funkcija
        -- kasniji returnovi mogu dodati još vrijednosti u tablicu
    end;
    $$ language plpgsql;

-- selektiranje iz povratne tablice
select * from multiple();

-- iznimke
create or replace function iznimke() returns void as $$
    declare
        -- varijable
        _v1 bool;
    begin
        -- naredbe
    exception
        -- nije moguće pozivati inimke nad svojim uvjetima
        -- moraju biti sql states
        when division_by_zero then
            -- nesto
        when others then
            -- prihvaća iznimke generalno
    end;
    $$ language plpgsql;

-- funkcija za okidač
-- ! ako je okidač tipa "before" onda povrat "null" spriječava akciju
    --  koja je pokirenula trigger
-- ! ako je vraćena vrijednost koja odgovara tablici na kojoj se radi,
    -- onda će se u daljnjem izvršavanju akcije koja je pokrenula
    -- trigger koristiti vraćena struktura
create function trigger_function() returns trigger as $$
    begin
        -- ! raising an exception in a function returns from function
        if (old.proizvod_naziv is distinct from new.proizvod_naziv) then
            raise exception 'ne smije se mijenjati naziv proizvoda';
        end if;
        return new;
    end;
    $$ language plpgsql;

-- okidači
create trigger ime_triggera before
    update of proizvod_naziv on proizvodi
    for each row when (
        old.proizvod_naziv like 'Pi%'
    )
    execute function trigger_function();

-- ako mijenjamo naziv "Pivo" napravit će se exception
update proizvodi set proizvod_naziv = 'abc' where
    proizvod_id = 75;

