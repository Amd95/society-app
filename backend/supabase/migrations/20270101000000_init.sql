-- Society app: initial schema, RLS and public RPCs.
-- Money is integer paise. Every table carries society_id and RLS enforces tenancy.

create extension if not exists pgcrypto;

create type member_role as enum ('owner', 'tenant', 'committee', 'treasurer', 'admin');
create type bill_status as enum ('unpaid', 'claimed', 'paid');
create type payment_mode as enum ('upi', 'cash', 'bank');
create type complaint_status as enum ('open', 'assigned', 'in_progress', 'closed');

-- ---------------------------------------------------------------- tables

create table societies (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    city text not null default 'Faridabad',
    upi_id text,
    upi_payee_name text,
    default_language text not null default 'hi' check (default_language in ('en', 'hi')),
    plan text not null default 'society' check (plan in ('free', 'society', 'rwa')),
    bill_due_day smallint not null default 10 check (bill_due_day between 1 and 28),
    created_by uuid references auth.users (id) on delete set null,
    created_at timestamptz not null default now()
);

create table homes (
    id uuid primary key default gen_random_uuid(),
    society_id uuid not null references societies (id) on delete cascade,
    label text not null,
    monthly_amount_paise bigint not null default 0 check (monthly_amount_paise >= 0),
    unique (society_id, label)
);

create table members (
    id uuid primary key default gen_random_uuid(),
    society_id uuid not null references societies (id) on delete cascade,
    home_id uuid references homes (id) on delete set null,
    user_id uuid references auth.users (id) on delete set null,
    name text not null,
    phone text not null,
    role member_role not null,
    directory_visible boolean not null default true,
    created_at timestamptz not null default now(),
    unique (society_id, user_id)
);
create index members_user_idx on members (user_id);

create table bills (
    id uuid primary key default gen_random_uuid(),
    society_id uuid not null references societies (id) on delete cascade,
    home_id uuid not null references homes (id) on delete cascade,
    month date not null check (extract(day from month) = 1),
    amount_paise bigint not null check (amount_paise > 0),
    status bill_status not null default 'unpaid',
    due_date date not null,
    -- Per-bill link token for the no-login resident page. Rotate by updating this column.
    public_token text not null unique default encode(gen_random_bytes(18), 'hex'),
    created_at timestamptz not null default now(),
    unique (home_id, month)
);
create index bills_society_month_idx on bills (society_id, month);

create table payments (
    id uuid primary key default gen_random_uuid(),
    bill_id uuid not null references bills (id) on delete cascade,
    society_id uuid not null references societies (id) on delete cascade,
    mode payment_mode not null,
    utr text check (utr is null or length(utr) <= 32),
    amount_paise bigint not null check (amount_paise > 0),
    claimed_at timestamptz not null default now(),
    confirmed_by uuid references auth.users (id) on delete set null,
    confirmed_at timestamptz
);
create index payments_bill_idx on payments (bill_id);

create table expenses (
    id uuid primary key default gen_random_uuid(),
    society_id uuid not null references societies (id) on delete cascade,
    amount_paise bigint not null check (amount_paise > 0),
    category text not null,
    vendor text,
    spent_on date not null default current_date,
    note text,
    receipt_path text,
    created_by uuid references auth.users (id) on delete set null,
    created_at timestamptz not null default now()
);
create index expenses_society_date_idx on expenses (society_id, spent_on desc);

create table complaints (
    id uuid primary key default gen_random_uuid(),
    society_id uuid not null references societies (id) on delete cascade,
    raised_by uuid not null references members (id) on delete cascade,
    title text not null,
    description text,
    photo_path text,
    status complaint_status not null default 'open',
    assignee uuid references members (id) on delete set null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table complaint_events (
    id uuid primary key default gen_random_uuid(),
    complaint_id uuid not null references complaints (id) on delete cascade,
    society_id uuid not null references societies (id) on delete cascade,
    actor uuid references members (id) on delete set null,
    to_status complaint_status not null,
    note text,
    created_at timestamptz not null default now()
);

create table notices (
    id uuid primary key default gen_random_uuid(),
    society_id uuid not null references societies (id) on delete cascade,
    title text not null,
    body text not null,
    posted_by uuid references members (id) on delete set null,
    created_at timestamptz not null default now()
);

create table polls (
    id uuid primary key default gen_random_uuid(),
    society_id uuid not null references societies (id) on delete cascade,
    question text not null,
    options jsonb not null check (jsonb_typeof(options) = 'array'),
    closes_at timestamptz,
    created_by uuid references members (id) on delete set null,
    created_at timestamptz not null default now()
);

create table poll_votes (
    poll_id uuid not null references polls (id) on delete cascade,
    home_id uuid not null references homes (id) on delete cascade,
    society_id uuid not null references societies (id) on delete cascade,
    option_index int not null check (option_index >= 0),
    voted_by uuid not null references members (id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (poll_id, home_id)
);

create table audit_log (
    id bigserial primary key,
    society_id uuid not null references societies (id) on delete cascade,
    actor uuid references auth.users (id) on delete set null,
    action text not null,
    entity text not null,
    entity_id uuid,
    detail jsonb,
    at timestamptz not null default now()
);
create index audit_society_idx on audit_log (society_id, at desc);

-- ---------------------------------------------------------------- helpers

create function is_society_member(sid uuid) returns boolean
language sql stable security definer set search_path = public as $$
    select exists (select 1 from members m where m.society_id = sid and m.user_id = auth.uid())
$$;

create function has_society_role(sid uuid, roles member_role[]) returns boolean
language sql stable security definer set search_path = public as $$
    select exists (
        select 1 from members m
        where m.society_id = sid and m.user_id = auth.uid() and m.role = any (roles)
    )
$$;

-- ---------------------------------------------------------------- RLS

alter table societies enable row level security;
alter table homes enable row level security;
alter table members enable row level security;
alter table bills enable row level security;
alter table payments enable row level security;
alter table expenses enable row level security;
alter table complaints enable row level security;
alter table complaint_events enable row level security;
alter table notices enable row level security;
alter table polls enable row level security;
alter table poll_votes enable row level security;
alter table audit_log enable row level security;

-- societies are created through create_society(); admins may edit.
create policy societies_select on societies for select using (is_society_member(id));
create policy societies_update on societies for update
    using (has_society_role(id, array['admin', 'treasurer']::member_role[]));

create policy homes_select on homes for select using (is_society_member(society_id));
create policy homes_write on homes for all
    using (has_society_role(society_id, array['admin', 'committee', 'treasurer']::member_role[]))
    with check (has_society_role(society_id, array['admin', 'committee', 'treasurer']::member_role[]));

-- Directory: members see rows that opted in, their own row, and committee sees everyone.
create policy members_select on members for select using (
    is_society_member(society_id)
    and (directory_visible or user_id = auth.uid()
         or has_society_role(society_id, array['admin', 'committee', 'treasurer']::member_role[]))
);
create policy members_write on members for all
    using (has_society_role(society_id, array['admin', 'committee', 'treasurer']::member_role[]))
    with check (has_society_role(society_id, array['admin', 'committee', 'treasurer']::member_role[]));

-- Bills and payments: committee sees all; residents see their own home's.
create policy bills_select on bills for select using (
    has_society_role(society_id, array['admin', 'committee', 'treasurer']::member_role[])
    or home_id in (select m.home_id from members m where m.user_id = auth.uid())
);
create policy bills_write on bills for all
    using (has_society_role(society_id, array['admin', 'treasurer']::member_role[]))
    with check (has_society_role(society_id, array['admin', 'treasurer']::member_role[]));

create policy payments_select on payments for select using (
    has_society_role(society_id, array['admin', 'committee', 'treasurer']::member_role[])
    or bill_id in (
        select b.id from bills b
        where b.home_id in (select m.home_id from members m where m.user_id = auth.uid())
    )
);
-- No direct writes to payments: use claim_payment / confirm_payment / record_cash_payment.

create policy expenses_select on expenses for select using (is_society_member(society_id));
create policy expenses_write on expenses for all
    using (has_society_role(society_id, array['admin', 'treasurer']::member_role[]))
    with check (has_society_role(society_id, array['admin', 'treasurer']::member_role[]));

create policy complaints_select on complaints for select using (is_society_member(society_id));
create policy complaints_insert on complaints for insert with check (
    raised_by in (select m.id from members m where m.user_id = auth.uid() and m.society_id = complaints.society_id)
);
create policy complaints_update on complaints for update
    using (has_society_role(society_id, array['admin', 'committee', 'treasurer']::member_role[]));

create policy complaint_events_select on complaint_events for select using (is_society_member(society_id));
create policy complaint_events_insert on complaint_events for insert with check (
    has_society_role(society_id, array['admin', 'committee', 'treasurer']::member_role[])
);

create policy notices_select on notices for select using (is_society_member(society_id));
create policy notices_write on notices for all
    using (has_society_role(society_id, array['admin', 'committee', 'treasurer']::member_role[]))
    with check (has_society_role(society_id, array['admin', 'committee', 'treasurer']::member_role[]));

create policy polls_select on polls for select using (is_society_member(society_id));
create policy polls_write on polls for all
    using (has_society_role(society_id, array['admin', 'committee', 'treasurer']::member_role[]))
    with check (has_society_role(society_id, array['admin', 'committee', 'treasurer']::member_role[]));

create policy poll_votes_select on poll_votes for select using (is_society_member(society_id));
create policy poll_votes_insert on poll_votes for insert with check (
    voted_by in (
        select m.id from members m
        where m.user_id = auth.uid() and m.society_id = poll_votes.society_id and m.home_id = poll_votes.home_id
    )
);

create policy audit_select on audit_log for select
    using (has_society_role(society_id, array['admin', 'committee', 'treasurer']::member_role[]));

-- ---------------------------------------------------------------- RPCs (authenticated)

create function create_society(
    p_name text, p_city text, p_upi_id text, p_payee_name text, p_admin_name text, p_phone text
) returns uuid
language plpgsql security definer set search_path = public as $$
declare sid uuid;
begin
    if auth.uid() is null then raise exception 'not_authenticated'; end if;
    insert into societies (name, city, upi_id, upi_payee_name, created_by)
    values (p_name, coalesce(p_city, 'Faridabad'), p_upi_id, p_payee_name, auth.uid())
    returning id into sid;
    insert into members (society_id, user_id, name, phone, role)
    values (sid, auth.uid(), p_admin_name, p_phone, 'admin');
    insert into audit_log (society_id, actor, action, entity, entity_id)
    values (sid, auth.uid(), 'create', 'society', sid);
    return sid;
end $$;

-- Links member rows pre-created by the committee (matched on the last 10 digits of the phone).
create function claim_membership() returns int
language plpgsql security definer set search_path = public as $$
declare n int; digits text;
begin
    digits := right(regexp_replace(coalesce(auth.jwt() ->> 'phone', ''), '\D', '', 'g'), 10);
    if auth.uid() is null or length(digits) < 10 then return 0; end if;
    update members set user_id = auth.uid()
    where user_id is null and right(regexp_replace(phone, '\D', '', 'g'), 10) = digits;
    get diagnostics n = row_count;
    return n;
end $$;

create function confirm_payment(p_payment_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare p payments%rowtype;
begin
    select * into p from payments where id = p_payment_id for update;
    if not found then raise exception 'payment_not_found'; end if;
    if not has_society_role(p.society_id, array['admin', 'treasurer']::member_role[]) then
        raise exception 'forbidden';
    end if;
    update payments set confirmed_by = auth.uid(), confirmed_at = now() where id = p.id;
    update bills set status = 'paid' where id = p.bill_id;
    insert into audit_log (society_id, actor, action, entity, entity_id)
    values (p.society_id, auth.uid(), 'confirm', 'payment', p.id);
end $$;

create function record_cash_payment(p_bill_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare b bills%rowtype; pid uuid;
begin
    select * into b from bills where id = p_bill_id for update;
    if not found then raise exception 'bill_not_found'; end if;
    if not has_society_role(b.society_id, array['admin', 'treasurer']::member_role[]) then
        raise exception 'forbidden';
    end if;
    if b.status = 'paid' then return; end if;
    insert into payments (bill_id, society_id, mode, amount_paise, confirmed_by, confirmed_at)
    values (b.id, b.society_id, 'cash', b.amount_paise, auth.uid(), now())
    returning id into pid;
    update bills set status = 'paid' where id = b.id;
    insert into audit_log (society_id, actor, action, entity, entity_id)
    values (b.society_id, auth.uid(), 'cash_payment', 'payment', pid);
end $$;

-- ---------------------------------------------------------------- RPCs (public, token based)

-- Everything the no-login resident page needs: one bill, society UPI details, public ledger.
create function get_public_bill(p_token text) returns jsonb
language sql stable security definer set search_path = public as $$
    select jsonb_build_object(
        'bill', jsonb_build_object(
            'month', b.month, 'amount_paise', b.amount_paise, 'status', b.status,
            'due_date', b.due_date, 'home_label', h.label),
        'society', jsonb_build_object(
            'name', s.name, 'upi_id', s.upi_id,
            'payee_name', coalesce(s.upi_payee_name, s.name), 'language', s.default_language),
        'ledger', jsonb_build_object(
            'collected_paise', coalesce((
                select sum(p.amount_paise) from payments p
                where p.society_id = s.id and p.confirmed_at is not null), 0),
            'spent_paise', coalesce((select sum(e.amount_paise) from expenses e where e.society_id = s.id), 0)),
        'expenses', coalesce((
            select jsonb_agg(jsonb_build_object(
                'spent_on', e.spent_on, 'category', e.category,
                'vendor', e.vendor, 'amount_paise', e.amount_paise) order by e.spent_on desc)
            from (select * from expenses where society_id = s.id order by spent_on desc limit 50) e), '[]'::jsonb)
    )
    from bills b
    join homes h on h.id = b.home_id
    join societies s on s.id = b.society_id
    where b.public_token = p_token
$$;

-- Resident taps "I've paid". Creates an unconfirmed payment; the treasurer confirms it.
create function claim_payment(p_token text, p_utr text default null) returns void
language plpgsql security definer set search_path = public as $$
declare b bills%rowtype; v_utr text := nullif(trim(p_utr), '');
begin
    select * into b from bills where public_token = p_token for update;
    if not found then raise exception 'invalid_token'; end if;
    if b.status = 'paid' then return; end if;
    if v_utr is not null and length(v_utr) > 32 then raise exception 'invalid_utr'; end if;
    if b.status = 'claimed' then
        update payments set utr = coalesce(v_utr, payments.utr), claimed_at = now()
        where bill_id = b.id and confirmed_at is null;
        return;
    end if;
    insert into payments (bill_id, society_id, mode, utr, amount_paise)
    values (b.id, b.society_id, 'upi', v_utr, b.amount_paise);
    update bills set status = 'claimed' where id = b.id;
end $$;

revoke execute on all functions in schema public from public;
grant execute on function get_public_bill(text), claim_payment(text, text) to anon, authenticated;
grant execute on function create_society(text, text, text, text, text, text),
    claim_membership(), confirm_payment(uuid), record_cash_payment(uuid) to authenticated;
