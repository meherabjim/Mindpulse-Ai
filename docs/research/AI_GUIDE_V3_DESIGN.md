# MindPulse AI Guide V3 — Design and Evidence Rules

## Purpose

AI Guide V3 replaces the local draft-only planner with an authenticated
mobile → Node → FastAPI reading-plan flow. It supports 1–30 user-selected
items and never fills the list with random books.

## Education profile

The profile stores separate fields for:

- education system;
- education level;
- current class, year or stage;
- SSC/HSC group or stream;
- board or curriculum;
- degree, major and semester;
- selected subjects;
- preferred plan language.

This avoids treating Class 10, SSC, HSC, BSc and Masters as one flat value.
The structure can later be mapped to UNESCO ISCED without exposing ISCED
codes in the user interface.

Official reference:
https://www.uis.unesco.org/en/methods-and-tools/isced/mapping-and-diagrams

Bangladesh curriculum and official textbook identity should be sourced from
NCTB when structured data is available. V3 allows NCTB to be recorded as the
identity source, but does not scrape or guess official textbook data.

Official reference:
https://nctb.gov.bd/

## Catalogue sources

### Google Books

Used for books and magazines. Supported metadata includes title, author,
publisher, publication date, identifiers, language and print type. The API
supports `printType=all`, `books`, or `magazines`.

Official references:
https://developers.google.com/books/docs/v1/reference/volumes/list
https://developers.google.com/books/docs/v1/using

### Crossref

Used for articles and research papers. It supplies scholarly metadata such as
DOI, title, author, publisher and publication date.

Official references:
https://api.crossref.org/
https://www.crossref.org/documentation/retrieve-metadata/rest-api/

### Open Library

Reserved as a later fallback for book/edition metadata. A production
integration must identify requests with a meaningful User-Agent, cache
responses and respect the documented rate limits.

Official reference:
https://openlibrary.org/developers/api

## Difficulty rule

Google Books, Crossref and Open Library are catalogue/metadata sources. V3 does
not claim that any of them provides an authoritative personal difficulty
rating.

- User-provided easy/medium/hard feedback receives high confidence.
- Unknown difficulty stays unknown.
- The first session becomes a short diagnostic reading session.
- Catalogue completeness affects identity evidence, not personal difficulty.

## Plan engine

The FastAPI engine is deterministic and explainable. It uses:

- exact selected item count;
- user priority;
- user difficulty feedback;
- selected subjects;
- preferred days and time;
- session length and weekly session count;
- optional target date.

Every session returns a focus, reason, confidence and difficulty evidence.
Accepted sessions can be added to the existing My Day local schedule.

## Current scope

V3 does not yet:

- sync reading plans to MySQL;
- import a complete weekly calendar into My Day;
- parse uploaded PDFs;
- calculate readability from copyrighted full text;
- claim LLM-generated academic correctness;
- automatically scrape NCTB pages.

Those should be separate reviewed phases after V3 is verified on both the
Pixel_9 emulator and physical phone.
