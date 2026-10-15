-- Shared schema + seed for all four Heroes apps (apps never create schema).
drop table if exists heroes;
create table heroes (
  id     bigserial primary key,
  name   text not null,
  alias  text not null,
  power  text not null,
  mentor text
);
insert into heroes (name, alias, power, mentor) values
  ('Barry Allen',  'The Flash', 'Super speed',      null),
  ('Dick Grayson', 'Robin',     'Acrobatics',       'Bruce Wayne'),
  ('Jason Todd',   'Robin',     'Marksmanship',     'Bruce Wayne'),
  ('Tim Drake',    'Robin',     'Detective skills', 'Bruce Wayne'),
  ('Damian Wayne', 'Robin',     'Assassin training','Bruce Wayne');
-- filler so GET-by-id spreads over 1000 rows
insert into heroes (name, alias, power, mentor)
  select 'Hero ' || g, 'Alias ' || g, 'Power ' || (g % 17), case when g % 3 = 0 then 'Barry Allen' end
  from generate_series(6, 1000) g;
analyze heroes;
