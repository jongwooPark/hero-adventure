-- ============================================================
--  슈퍼 히어로 대모험 · 점수판(Top 5) 창고 설정
--  Supabase 프로젝트의 "SQL Editor"에 그대로 붙여넣고 Run 하세요.
--  (이름 입력 없이, 기기별로 점수를 누적하는 구조)
-- ============================================================

-- 1) 점수 저장 테이블
create table if not exists public.scores (
  player_id   text primary key,
  nickname    text not null,
  total_score bigint not null default 0,
  best_score  integer not null default 0,
  plays       integer not null default 0,
  updated_at  timestamptz not null default now()
);

-- 2) 보안(RLS) 켜기 — 함부로 점수를 조작하지 못하게 보호
alter table public.scores enable row level security;

-- 3) 누구나 "순위표 읽기"는 가능하도록 허용 (읽기 전용)
drop policy if exists "read scores" on public.scores;
create policy "read scores" on public.scores
  for select using (true);

-- 4) 점수 누적 함수 — 이름 없이, 양수 점수만 안전하게 더해줌
create or replace function public.add_score(p_id text, p_nick text, p_score integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_score is null or p_score <= 0 then
    return;
  end if;
  insert into public.scores (player_id, nickname, total_score, best_score, plays, updated_at)
  values (p_id, coalesce(nullif(p_nick, ''), '히어로'), p_score, p_score, 1, now())
  on conflict (player_id) do update
    set total_score = public.scores.total_score + excluded.total_score,
        best_score  = greatest(public.scores.best_score, excluded.best_score),
        nickname    = excluded.nickname,
        plays       = public.scores.plays + 1,
        updated_at  = now();
end;
$$;

-- 5) 앱(익명 사용자)이 점수 누적 함수를 사용할 수 있게 허용
grant execute on function public.add_score(text, text, integer) to anon;
