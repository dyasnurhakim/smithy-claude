# Wield Playbook — Java / JVM

## API — Spring Boot

- Prefer in-process: `MockMvc` (web layer) or `@SpringBootTest(webEnvironment
  = RANDOM_PORT)` + `TestRestTemplate`/`WebTestClient` for full-stack flows.
  Put QA flows in a scratch test class under `src/test/java` in a clearly
  named `qa` package — ask before committing it.
- Else run the real jar (`java -jar target/app.jar` or `./gradlew bootRun`),
  poll the actuator/health or root URL for readiness, drive with curl scripts.

## API — non-Spring

- Run the real service per its README/Main class; drive with `curl` or
  `java.net.http.HttpClient` scripts.

## Per endpoint flow

- Happy path; validation failures (assert the 4xx AND the error body shape —
  Spring's default error JSON vs custom advice matters); auth (401/403);
  not-found; malformed JSON; wrong content-type.
- Error responses must not leak stack traces or internals — a Whitelabel
  error page with a stack trace, or `"trace": "..."` in the body, = High.
- Side-effect checks: after mutating calls, read back and assert state.

## CLI

- `java -jar tool.jar` invocations: valid args, invalid args (usage + nonzero
  exit), `--help`, empty/huge stdin. Assert exit codes and stream separation.

## Console/log hygiene

- Watch the app log during flows: any unhandled-exception stack trace during
  a nominal flow is at least High, even when the HTTP response looked fine.
