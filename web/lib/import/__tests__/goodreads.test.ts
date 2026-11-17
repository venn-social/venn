import { describe, expect, it } from "vitest";
import { parseDate, parseGoodreadsExport, parseISBN } from "@/lib/import/goodreads";

const HEADER =
  "Book Id,Title,Author,Author l-f,Additional Authors,ISBN,ISBN13,My Rating,Average Rating,Publisher,Binding,Number of Pages,Year Published,Original Publication Year,Date Read,Date Added,Bookshelves,Bookshelves with positions,Exclusive Shelf,My Review,Spoiler,Private Notes,Read Count,Owned Copies";

const sample = [
  HEADER,
  '2767052,"The Hunger Games (The Hunger Games, #1)",Suzanne Collins,"Collins, Suzanne",,="0439023483",="9780439023481",5,4.33,Scholastic Press,Hardcover,374,2008,2008,2023/01/15,2022/12/01,,,read,,,,1,0',
  '1,Middlemarch,George Eliot,"Eliot, George",,="",="",4,3.98,Penguin,Paperback,880,2003,1871,,2021/05/02,,,read,,,,1,0',
  '2,Stoner,John Williams,"Williams, John",,="",="9781590171998",3,4.3,NYRB,Paperback,288,2006,1965,2020/03/03,2020/01/01,,,read,,,,1,0',
  '3,Ulysses,James Joyce,"Joyce, James",,="",="",0,3.7,Vintage,Paperback,783,1990,1922,,2019/01/01,,,read,,,,1,0',
  '4,Piranesi,Susanna Clarke,"Clarke, Susanna",,="",="",0,4.2,Bloomsbury,Hardcover,272,2020,2020,,2024/02/02,to-read,to-read (#1),to-read,,,,0,0',
  '5,The Overstory,Richard Powers,"Powers, Richard",,="",="",0,4.1,Norton,Hardcover,502,2018,2018,,2024/03/03,currently-reading,,currently-reading,,,,0,0',
  '6,Infinite Jest,David Foster Wallace,"Wallace, David Foster",,="",="",0,4.2,Little Brown,Paperback,1079,2006,1996,,2018/01/01,did-not-finish,,did-not-finish,,,,0,0',
  '7,Bad Book,Some One,"One, Some",,="",="",1,2.0,X,Paperback,100,2010,2010,2015/06/06,2015/01/01,,,read,,,,1,0'
].join("\n");

describe("parseGoodreadsExport", () => {
  const { entries, problems } = parseGoodreadsExport(sample);
  const byTitle = new Map(entries.map((e) => [e.title, e]));

  it("imports read, to-read and currently-reading, and reports custom shelves", () => {
    expect(entries).toHaveLength(7);
    expect(problems).toEqual([
      { file: "goodreads_library_export.csv", line: 8, reason: "unsupportedShelf" }
    ]);
  });

  it("rates read books on the shared star scale", () => {
    expect(byTitle.get("The Hunger Games (The Hunger Games, #1)")).toMatchObject({
      action: "rated",
      rating: 5,
      creator: "Suzanne Collins",
      isbn: "9780439023481",
      year: 2008,
      consumedAt: "2023-01-15"
    });
    expect(byTitle.get("Middlemarch")).toMatchObject({ action: "rated", rating: 3, year: 1871 });
    expect(byTitle.get("Stoner")).toMatchObject({ action: "logged", rating: null });
    expect(byTitle.get("Bad Book")).toMatchObject({ action: "rated", rating: 1 });
  });

  it("logs unrated read books and dates them by Date Added when there is no read date", () => {
    expect(byTitle.get("Ulysses")).toMatchObject({
      action: "logged",
      rating: null,
      consumedAt: "2019-01-01"
    });
  });

  it("saves to-read and currently-reading books", () => {
    expect(byTitle.get("Piranesi")).toMatchObject({ action: "saved", consumedAt: "2024-02-02" });
    expect(byTitle.get("The Overstory")).toMatchObject({ action: "saved", rating: null });
  });

  it("marks every entry as a book", () => {
    expect(entries.every((e) => e.kind === "book")).toBe(true);
  });

  it("skips a repeated Book Id and reports a missing title", () => {
    const text = [
      HEADER,
      sample.split("\n")[2],
      sample.split("\n")[2],
      "9,,Nobody,,,,,0,,,,,,,,,,,read"
    ].join("\n");
    const result = parseGoodreadsExport(text);
    expect(result.entries).toHaveLength(1);
    expect(result.problems).toEqual([
      { file: "goodreads_library_export.csv", line: 4, reason: "missingTitle" }
    ]);
  });
});

describe("parseISBN", () => {
  it("unwraps Goodreads' spreadsheet formulas", () => {
    expect(parseISBN('="9780439023481"')).toBe("9780439023481");
    expect(parseISBN('="043902348X"')).toBe("043902348X");
  });

  it("rejects empty and malformed values", () => {
    expect(parseISBN('=""')).toBeNull();
    expect(parseISBN("12345")).toBeNull();
    expect(parseISBN(undefined)).toBeNull();
  });
});

describe("parseDate", () => {
  it("converts Goodreads' slashes", () => {
    expect(parseDate("2023/01/15")).toBe("2023-01-15");
    expect(parseDate("15/01/2023")).toBeNull();
    expect(parseDate("")).toBeNull();
  });
});
