# Wield Playbook — Java / JVM

## API — Spring Boot

- Prefer in-process: `MockMvc` (web layer) or `@SpringBootTest(webEnvironment
  = RANDOM_PORT)` + `TestRestTemplate` / `WebTestClient` for full-stack flows.
  Put QA flows in a scratch test class under `src/test/java`, in a clearly
  named `qa` package — ask before committing it.
- Or run the real jar (`java -jar target/app.jar` or `./gradlew bootRun`),
  poll the actuator/health or root URL until it is ready, and drive it with
  curl scripts.

## API — non-Spring

- Run the real service as its README / Main class says; drive it with
  `curl` or `java.net.http.HttpClient` scripts.

## Per endpoint flow

- Happy path; validation failures (check the 4xx AND the shape of the error
  body — Spring's default error JSON vs custom advice matters); auth
  (401/403); not-found; malformed JSON; wrong content-type.
- Error responses must not leak stack traces or internals — a Whitelabel
  error page with a stack trace, or `"trace": "..."` in the body, = High.
- Side effects: after a call that changes data, read it back and check it.

## CLI

- `java -jar tool.jar` calls: valid args, invalid args (usage + nonzero
  exit), `--help`, empty or huge stdin. Check exit codes, and that stdout
  and stderr stay separate.

## Console / log hygiene

- Watch the app log during flows: an unhandled-exception stack trace during
  a normal flow is at least High, even when the HTTP response looked fine.
