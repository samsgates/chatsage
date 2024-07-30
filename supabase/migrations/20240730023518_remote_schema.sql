
SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

CREATE EXTENSION IF NOT EXISTS "pgsodium" WITH SCHEMA "pgsodium";

COMMENT ON SCHEMA "public" IS 'standard public schema';

CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";

CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "extensions";

CREATE OR REPLACE FUNCTION "public"."match_vectors"("query_embedding" "extensions"."vector", "match_threshold" double precision, "match_count" integer) RETURNS TABLE("id" bigint, "content" "text", "similarity" double precision)
    LANGUAGE "sql" STABLE
    AS $$
  select
    vectors.id,
    vectors.content,
    1 - (vectors.embedding <=> query_embedding) as similarity
  from vectors
  where vectors.embedding <=> query_embedding < 1 - match_threshold
  order by vectors.embedding <=> query_embedding
  limit match_count;
$$;

ALTER FUNCTION "public"."match_vectors"("query_embedding" "extensions"."vector", "match_threshold" double precision, "match_count" integer) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."match_vectors"("query_embedding" "extensions"."vector", "match_count" integer DEFAULT NULL::integer, "filter" "jsonb" DEFAULT '{}'::"jsonb") RETURNS TABLE("id" bigint, "content" "text", "metadata" "jsonb", "embedding" "jsonb", "similarity" double precision)
    LANGUAGE "plpgsql"
    AS $$
#variable_conflict use_column
begin
  return query
  select
    id,
    content,
    metadata,
    (embedding::text)::jsonb as embedding,
    1 - (vectors.embedding <=> query_embedding) as similarity
  from vectors
  where metadata @> filter
  order by vectors.embedding <=> query_embedding
  limit match_count;
end;
$$;

ALTER FUNCTION "public"."match_vectors"("query_embedding" "extensions"."vector", "match_count" integer, "filter" "jsonb") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";

CREATE TABLE IF NOT EXISTS "public"."chat_logs" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "message" "text",
    "role" "text",
    "internal_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "text" NOT NULL,
    "chatbot_internal_id" "uuid" NOT NULL
);

ALTER TABLE "public"."chat_logs" OWNER TO "postgres";

ALTER TABLE "public"."chat_logs" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."chat_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

CREATE TABLE IF NOT EXISTS "public"."chatbots" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "name" "text",
    "user_auth_id" "uuid" NOT NULL,
    "internal_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "is_public" boolean DEFAULT false NOT NULL
);

ALTER TABLE "public"."chatbots" OWNER TO "postgres";

ALTER TABLE "public"."chatbots" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."projects_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

CREATE TABLE IF NOT EXISTS "public"."urls" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "chatbot_internal_id" "uuid" NOT NULL,
    "status" "text",
    "url" "text" NOT NULL
);

ALTER TABLE "public"."urls" OWNER TO "postgres";

ALTER TABLE "public"."urls" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."urls_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" bigint NOT NULL,
    "email" "text",
    "auth_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."users" OWNER TO "postgres";

ALTER TABLE "public"."users" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."users_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

CREATE TABLE IF NOT EXISTS "public"."vectors" (
    "id" bigint NOT NULL,
    "content" "text",
    "embedding" "extensions"."vector",
    "metadata" "jsonb"
);

ALTER TABLE "public"."vectors" OWNER TO "postgres";

ALTER TABLE "public"."vectors" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."vectors_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

ALTER TABLE ONLY "public"."chat_logs"
    ADD CONSTRAINT "chat_logs_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."chatbots"
    ADD CONSTRAINT "chatbots_user_auth_id_key" UNIQUE ("user_auth_id");

ALTER TABLE ONLY "public"."chatbots"
    ADD CONSTRAINT "projects_internal_id_key" UNIQUE ("internal_id");

ALTER TABLE ONLY "public"."chatbots"
    ADD CONSTRAINT "projects_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."urls"
    ADD CONSTRAINT "urls_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_internal_id_key" UNIQUE ("auth_id");

ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."vectors"
    ADD CONSTRAINT "vectors_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."chat_logs"
    ADD CONSTRAINT "chat_logs_chatbot_internal_id_fkey" FOREIGN KEY ("chatbot_internal_id") REFERENCES "public"."chatbots"("internal_id");

ALTER TABLE ONLY "public"."chatbots"
    ADD CONSTRAINT "projects_user_auth_id_fkey" FOREIGN KEY ("user_auth_id") REFERENCES "public"."users"("auth_id");

ALTER TABLE ONLY "public"."urls"
    ADD CONSTRAINT "urls_chatbot_internal_id_fkey" FOREIGN KEY ("chatbot_internal_id") REFERENCES "public"."chatbots"("internal_id");

CREATE POLICY "Enable delete for authenticated users only" ON "public"."urls" FOR DELETE TO "authenticated" USING (true);

CREATE POLICY "Enable insert for authenticated users only" ON "public"."chatbots" FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "Enable insert for authenticated users only" ON "public"."users" FOR INSERT TO "authenticated" WITH CHECK (true);

CREATE POLICY "Enable select for authenticated users only" ON "public"."chat_logs" FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "Enable select for authenticated users only" ON "public"."urls" FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "Enable select for users based on user_id" ON "public"."chatbots" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_auth_id"));

CREATE POLICY "Enable select for users based on user_id" ON "public"."users" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "auth_id"));

CREATE POLICY "Enable update for authenticated users only" ON "public"."urls" FOR UPDATE TO "authenticated" USING (true);

CREATE POLICY "Enable update for users based on user_id" ON "public"."chatbots" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_auth_id"));

ALTER TABLE "public"."chat_logs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."chatbots" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."urls" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;

ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";

GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

GRANT ALL ON TABLE "public"."chat_logs" TO "anon";
GRANT ALL ON TABLE "public"."chat_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."chat_logs" TO "service_role";

GRANT ALL ON SEQUENCE "public"."chat_logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."chat_logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."chat_logs_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."chatbots" TO "anon";
GRANT ALL ON TABLE "public"."chatbots" TO "authenticated";
GRANT ALL ON TABLE "public"."chatbots" TO "service_role";

GRANT ALL ON SEQUENCE "public"."projects_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."projects_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."projects_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."urls" TO "anon";
GRANT ALL ON TABLE "public"."urls" TO "authenticated";
GRANT ALL ON TABLE "public"."urls" TO "service_role";

GRANT ALL ON SEQUENCE "public"."urls_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."urls_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."urls_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";

GRANT ALL ON SEQUENCE "public"."users_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."users_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."users_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."vectors" TO "anon";
GRANT ALL ON TABLE "public"."vectors" TO "authenticated";
GRANT ALL ON TABLE "public"."vectors" TO "service_role";

GRANT ALL ON SEQUENCE "public"."vectors_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."vectors_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."vectors_id_seq" TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";

RESET ALL;
