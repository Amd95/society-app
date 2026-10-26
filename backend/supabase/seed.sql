-- Local/dev seed: one demo society with three homes and April 2027 bills.
-- The resident page can be tried at webResident/index.html?t=demo-token-a1

insert into societies (id, name, city, upi_id, upi_payee_name)
values ('00000000-0000-0000-0000-0000000000a1', 'Demo Greenfield RWA', 'Faridabad', 'demo@upi', 'Demo Greenfield RWA');

insert into homes (id, society_id, label, monthly_amount_paise) values
    ('00000000-0000-0000-0000-00000000b001', '00000000-0000-0000-0000-0000000000a1', 'A-1', 50000),
    ('00000000-0000-0000-0000-00000000b002', '00000000-0000-0000-0000-0000000000a1', 'A-2', 50000),
    ('00000000-0000-0000-0000-00000000b003', '00000000-0000-0000-0000-0000000000a1', 'A-3', 50000);

insert into bills (society_id, home_id, month, amount_paise, due_date, public_token) values
    ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000b001', '2027-04-01', 50000, '2027-04-10', 'demo-token-a1'),
    ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000b002', '2027-04-01', 50000, '2027-04-10', 'demo-token-a2'),
    ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000b003', '2027-04-01', 50000, '2027-04-10', 'demo-token-a3');

insert into expenses (society_id, amount_paise, category, vendor, spent_on) values
    ('00000000-0000-0000-0000-0000000000a1', 800000, 'Guard salary', 'Ramesh', '2027-04-01'),
    ('00000000-0000-0000-0000-0000000000a1', 120000, 'Motor repair', 'Sharma Electricals', '2027-04-05');
