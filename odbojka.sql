---------------------------------- RELACIJE ------------------------------------

create table klubovi (
    klub_id             int,    -- primary

    klub_naziv          varchar(40) not null,
    datum_osnivanja     date,
    grad                varchar(15),
    drzava              varchar(30),
    telefon             varchar(24),
    aktivan             bool,

    constraint pk_klubovi primary key (klub_id)
);

create table kola (
    kolo_datum          date,   -- primary

    kolo                smallint not null,

    constraint pk_kola primary key (kolo_datum)
);

create table utakmice (
    utakmica_id         int,    -- primary

    datum_utakmice      date not null,   -- foreign
    klub_A_id           int not null,    -- foreign
    klub_B_id           int not null,    -- foreign

    set_1               varchar(5),
    set_2               varchar(5),
    set_3               varchar(5),
    set_4               varchar(5),
    set_5               varchar(5),
    rezultat_ukupni     varchar(3) not null, -- konačni rezultat u setovima

    constraint pk_utakmice primary key (utakmica_id),
    constraint fk_datum_utakmice foreign key (datum_utakmice)
        references kola (kolo_datum),
    constraint fk_klub_u_utakmice foreign key (klub_A_id)
        references klubovi (klub_id) on delete restrict,
    constraint fk_klub_2_u_utakmice foreign key (klub_B_id)
        references klubovi (klub_id) on delete restrict,

    constraint format_bodova check (
        set_1 similar to '[0-9]{2}:[0-9]{2}' and
        set_2 similar to '[0-9]{2}:[0-9]{2}' and
        set_3 similar to '[0-9]{2}:[0-9]{2}'),
    constraint format_ukupnog_rezultata check (
        rezultat_ukupni similar to '[0-5]:[0-5]')
);

create table igraci (
    igrac_id            int,    -- primary

    klub_id             int not null,    -- foreign

    igrac_ime           varchar(15) not null,
    igrac_prezime       varchar(15) not null,
    starost             smallint,
    pozicija            varchar(15),

    constraint pk_igraci primary key (igrac_id),
    constraint fk_klub_u_igraci foreign key (klub_id)
        references klubovi (klub_id) on delete restrict,

    constraint format_pozicije check (
        pozicija in ('primač', 'tehničar', 'korektor-kolektor',
                     'srednji-bloker', 'libero' ) )
);

create table statistika_igraca (
    igrac_id            int,    -- foreign \
                                --          | primary
    utakmica_id         int,    -- foreign /

    br_bodova           smallint not null,
    br_aseva            smallint not null,
    br_blokova          smallint not null,

    constraint pk_statistika_igraca primary key (igrac_id, utakmica_id),
    constraint fk_igrac_id_u_statistici foreign key (igrac_id) references
        igraci (igrac_id) on delete restrict,
    constraint fk_utakmica_id_u_statistici foreign key (utakmica_id) references
        utakmice (utakmica_id) on delete restrict,

    constraint br_veci_od_nula check (
        br_bodova > -1 and br_aseva > -1 and br_blokova > -1 )
);

create table stanje_lige (
    klub_id             int,    -- foreign, primary

    br_bodova           int,
    br_pobjeda          int,
    br_utakmica         int,
    br_osv_setova       int,
    br_osv_poena        int,

    constraint pk_stanje_lige primary key (klub_id),
    constraint fk_klub_id_u_stanju_lige foreign key (klub_id)
        references klubovi (klub_id) on delete restrict,

    constraint prirodni_brojevi check (
        br_bodova > -1 and br_pobjeda > -1 and br_utakmica > -1 and
        br_osv_poena > -1 and br_osv_setova > -1 )
);

------------------------------ FUNKCIJE I OKIDAČI --------------------------------

-- Prihvaća argumente poput 'bodovi', 'br aseva', 'broj_blokova' i sl.
create or replace function najbolji_igraci(_kategorija varchar(12)) returns table
    (id_igraca int, prosjek_poena_u_kategoriji real, rang_igraca int) as $$
    declare
        _max_prosjek        real; -- za traženje trenutnog najboljeg igrača
        _id                 int; -- za spremanje id-a igrača
        _zadnja_pozicija    int; -- brojač za rangiranje igrača

        _prosjek_poena      real; -- za spremanje prosjeka bodova po svim
                                 -- utakmicama igrača
    begin
        _zadnja_pozicija = 0; -- inicijalizacija

        -- Ovdje se spremaju samo vrijednosti koje nas zanimaju
        -- na temlju argumenta funkcje.
        create temp table if not exists id_poeni (
            id              int, -- sadrži duplikate
            poeni           smallint
        );

        -- Ova relacija sadrži prosjek promatranih poena
        -- za svakog igrača.
        create temp table if not exists id_prosjek (
            id              int unique,
            prosjek         real
        );

        -- Provejeravamo unos korisnika i spremamo promatranu
        -- kategoriju uspjeha u tablicu id_poeni.
        if _kategorija similar to '%bodov_' then
            insert into id_poeni
                select igrac_id, br_bodova from statistika_igraca;
        elsif _kategorija similar to '%asev_' then
            insert into id_poeni
                select igrac_id, br_aseva from statistika_igraca;
        elsif _kategorija similar to '%blokov_' then
            insert into id_poeni
                select igrac_id, br_blokova from statistika_igraca;
        else
            raise exception 'pogrešna kategorija statistike';
        end if;

        -- Vadimo podatke iz statistike za igrače i svakom
        -- igraču pridružujemo prosjek poena kategorije po utakmicama.
        for _id in
            select distinct id from id_poeni
        loop
            _prosjek_poena = (select avg(poeni) from id_poeni p where p.id = _id);
            insert into id_prosjek values (_id,_prosjek_poena);
        end loop;

        alter table id_prosjek
            add column pozicija int; -- određuje rang igrača (1 najbolji)

        -- Trenutno su u svakom retku vrijednosti pozicije koja modelira
        -- poredak jednake null.
        -- Sve dok  postoji redak s null vrijednosti pronalazimo
        -- najboljeg takvog igrača i dodjeljujemo mu rang.

        while exists(select * from id_prosjek where pozicija isnull)
        loop
            _max_prosjek = (select max(prosjek) from id_prosjek where pozicija isnull);

                -- Sada svim igračima s istim brojem poena dodjeljujemo istu poziciju
            _zadnja_pozicija = 1 + _zadnja_pozicija;
            for _id in
                select id from id_prosjek where prosjek = _max_prosjek
            loop
                update id_prosjek q set pozicija = _zadnja_pozicija where q.id = _id;
            end loop;

        end loop;

        return query
        select * from id_prosjek order by pozicija asc;

        drop table id_poeni;
        drop table id_prosjek;
    end;
    $$ language plpgsql;

-- Vraća broj bodova koje su osvojili timovi na temelju
-- rezultata utakmice.
create or replace function
    bodovanje(_rez_a int, _rez_b int) returns
        table (bodovi_a int, bodovi_b int) as $$
    begin
        if _rez_a = 3 and (_rez_b = 1 or _rez_b = 0) then
            bodovi_a = 3;
            bodovi_b = 0;
            return next;
        elsif _rez_a = 3 and _rez_b = 2 then
            bodovi_a = 2;
            bodovi_b = 1;
            return next;
        elsif _rez_a = 2 and _rez_b = 3 then
            bodovi_a = 1;
            bodovi_b = 2;
            return next;
        elsif _rez_b = 3 and (_rez_a = 0 or _rez_a = 1) then
            bodovi_a = 0;
            bodovi_b = 3;
            return next;
        else
            raise exception 'nemoguće dodijeliti bodove';
        end if;
    end;
    $$ language plpgsql;

-- Koristi se kod pokušaja unosa podataka o utakmici
-- za provjere valjanosti podataka koje je nemoguće
-- obuhvatiti conastraint-ima i za ažuriranje stanja lige.
create or replace function provjera_utakmice() returns trigger as $$
    declare
        _setovi             varchar(5) array[5];
        -- _setovi_a[i] je broj poena koje je tim
        -- a osvojio u i-tom setu.
        _setovi_a           int array[5];
        _setovi_b           int array[5];
        _konacni_a          int; -- uneseni rezultat u setovima za a
        _konacni_b          int; -- uneseni rezultat u setovima za b

        -- Iduće vrijednosti spremamo u stanje_lige nakon unosa utakmice
        _ukupno_setova_a    int;
        _ukupno_setova_b    int;

        _ukupno_poena_a     int;
        _ukupno_poena_b     int;

        _br_bodova_a        int;
        _br_bodova_b        int;

        _pobjeda_a          int;
        _pobjeda_b          int;
    begin
        -- inicijalizacija
        _ukupno_poena_a = 0;
        _ukupno_poena_b = 0;
        _ukupno_setova_a = 0;
        _ukupno_setova_b = 0;

        _setovi = array[new.set_1, new.set_2, new.set_3, new.set_4, new.set_5];
        _konacni_a = cast( substring(new.rezultat_ukupni from 1 for 1) as int );
        _konacni_b = cast( substring(new.rezultat_ukupni from 3 for 1) as int );

        for i in 1..5 loop
             _setovi_a[i] = cast( substring(_setovi[i] from 1 for 2) as int );
             _setovi_b[i] = cast( substring(_setovi[i] from 4 for 2) as int );
        end loop;

        -- Zbrajamo ukupan broj poena kroz setove.
        for i in 1..5 loop
            if not _setovi_a[i] isnull then
            _ukupno_poena_a = _ukupno_poena_a + _setovi_a[i];
            _ukupno_poena_b = _ukupno_poena_b + _setovi_b[i];
            end if;
        end loop;

        -- Pretvaramo bodove u setovima u 1 ako je pobjeda, a 0 inače
        -- Obuhvaća i slučaj kad je null.
        if _setovi_a[5] = 15 then
           _setovi_a[5] = 1; else _setovi_a[5] = 0;
        end if;
        if _setovi_b[5] = 15 then
            _setovi_b[5] = 1; else _setovi_b[5] = 0;
        end if;

        for i in 1..4 loop
            if _setovi_a[i] = 25 then
                _setovi_a[i] = 1; else _setovi_a[i] = 0;
            end if;
            if _setovi_b[i] = 25 then
                _setovi_b[i] = 1; else _setovi_b[i] = 0;
            end if;
        end loop;

        -- Zbrajamo pobjede po setovima i uspoređujemo
        -- s konačnim unsenim rezultatom.
        for i in 1..5 loop
            _ukupno_setova_a = _ukupno_setova_a + _setovi_a[i];
            _ukupno_setova_b = _ukupno_setova_b + _setovi_b[i];
        end loop;

        -- Provjeravamo neke bitne uvjete za valjanost unosa
        if (not _ukupno_setova_a = _konacni_a) or
           (not _ukupno_setova_b = _konacni_b) then
                raise exception 'podaci o bodovima nisu konzistentni';
        end if;

        if (not 3 = _konacni_a) and (not 3 = _konacni_b) then
            raise exception 'nema pobjednika';
        end if;

        -- U ovom dijelu koda su podaci ispravno uneseni (više-manje).
        -- Računamo broj osvojenih bodova za rezultat utakmice.
        select bodovi_a, bodovi_b from
            bodovanje(_konacni_a, _konacni_b) into
                _br_bodova_a, _br_bodova_b;

        if _konacni_a = 3 then
            _pobjeda_a = 1;
            _pobjeda_b = 0;
        else
            _pobjeda_a = 0;
            _pobjeda_b  =1;
        end if;

        -- U slučaju da ne postoji informacija o klubu u stanje_lige.
        if not exists(select * from stanje_lige
            where klub_id = new.klub_a_id) then
            insert into stanje_lige values
                (new.klub_a_id, _br_bodova_a, _pobjeda_a,
                1, _ukupno_setova_a, _ukupno_poena_a);
        else
            -- U slučaju da već postoji zapis u stanje_lige.
            update stanje_lige set
                br_bodova = br_bodova + _br_bodova_a,
                br_pobjeda = br_pobjeda + _pobjeda_a,
                br_utakmica = br_utakmica + 1,
                br_osv_setova = br_osv_setova + _ukupno_setova_a,
                br_osv_poena = br_osv_poena + _ukupno_poena_a
                    where klub_id = new.klub_a_id;
        end if;

        -- Analogno kao za ekipu a.
        if not exists(select * from stanje_lige
            where klub_id = new.klub_b_id) then
            insert into stanje_lige values
                (new.klub_b_id, _br_bodova_b, _pobjeda_b,
                1, _ukupno_setova_b, _ukupno_poena_b);
        else
            update stanje_lige set
                br_bodova = br_bodova + _br_bodova_b,
                br_pobjeda = br_pobjeda + _pobjeda_b,
                br_utakmica = br_utakmica + 1,
                br_osv_setova = br_osv_setova + _ukupno_setova_b,
                br_osv_poena = br_osv_poena + _ukupno_poena_b
                    where klub_id = new.klub_b_id;
        end if;

        return new;
    end;
    $$ language plpgsql;

create trigger unos_utakmice before insert on
    utakmice for each row
    execute function provjera_utakmice();

---------------------------------- UNOS PODATAKA ------------------------------------

insert into klubovi values
    (1,'Pantera','1-1-2010','Zagreb','Hrvatska','01 3754 226',true),
    (2,'Mladost','may-17-2002','zagreb','Hrvatska','01 3722 883',true);

insert into kola values
    ('oct-8-2022',1), ('oct-9-2022',1), ('nov-8-2022',2), ('nov-10-2022',2);

insert into utakmice values
    (1,'oct-8-2022', 1, 2, '25:14', '25:13', '25:19', null, null, '3:0'),
    (2,'oct-9-2022', 1, 2, '15:25', '25:17', '25:20', '25:20', null, '3:1'),
    (3,'nov-8-2022', 1, 2, '24:25', '17:25', '25:24', '25:21', '12:15', '2:3'),
    (4,'nov-8-2022', 1, 2, '24:25', '17:25', '25:24', '25:21', '12:15', '2:3'),
    (6,'nov-8-2022', 1, 2, '24:25', '17:25', '25:24', '25:21', '12:15', '2:3');

-- iduci unos ne postuje pk, fk ni format ukuopnog rezultata
-- insert into utakmice values
-- (4,'oct-8-2022', 3, 2, '25:14', '25:13', '25:19', 'm:0');

insert into igraci values
    (1,1,'Petar','Nikčić',27,'libero'),
    (2,2,'Marko','Lisnić',25,'tehničar'),
    (3,1,'Ivan','Horvat',23,'primač');

insert into statistika_igraca values
    (1,1,5,6,7),(2,1,7,5,6),
    (3,2,5,5,5), (1,2,4,5,6);

------------------------------- TESTIRANJE FUNKCIJA ------------------------------

select * from najbolji_igraci('asevi');