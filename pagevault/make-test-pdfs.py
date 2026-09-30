"""Generate PageVault feasibility-test PDFs.

Structural fixtures only: these cover the cases that are awkward to find on demand
(deep outline, no outline, encrypted, corrupt, very long). A real scanned book is
still the right input for the memory-pressure part of the gate.
"""
import io
import pathlib
import sys

from PIL import Image
from pypdf import PdfReader, PdfWriter

OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
OUT.mkdir(parents=True, exist_ok=True)

PAGE_W, PAGE_H = 612, 792


def esc(text):
    return text.replace("\\", r"\\").replace("(", r"\(").replace(")", r"\)")


def assemble(objects, root_ref):
    """Write a PDF from a list of already-serialized object bodies (1-indexed)."""
    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for number, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{number} 0 obj\n".encode()
        out += body
        out += b"\nendobj\n"
    xref_at = len(out)
    count = len(objects) + 1
    out += f"xref\n0 {count}\n".encode()
    out += b"0000000000 65535 f \n"
    for off in offsets:
        out += f"{off:010d} 00000 n \n".encode()
    out += f"trailer\n<< /Size {count} /Root {root_ref} 0 R >>\nstartxref\n{xref_at}\n%%EOF\n".encode()
    return bytes(out)


def text_pdf(pages, heading):
    """Real text pages (vector Helvetica), so text rendering and search behave realistically."""
    kids = " ".join(f"{4 + 2 * i} 0 R" for i in range(pages))
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        f"<< /Type /Pages /Kids [{kids}] /Count {pages} >>".encode(),
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    ]
    for i in range(pages):
        content_ref = 5 + 2 * i
        objects.append(
            f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {PAGE_W} {PAGE_H}] "
            f"/Resources << /Font << /F1 3 0 R >> >> /Contents {content_ref} 0 R >>".encode()
        )
        lines = [
            (72, 700, 26, f"Page {i + 1} of {pages}"),
            (72, 660, 14, heading),
        ]
        body = 620
        for n in range(22):
            lines.append((72, body, 11,
                          f"Line {n + 1} on page {i + 1}. "
                          "The quick brown fox jumps over the lazy dog, repeatedly and without complaint."))
            body -= 22
        stream = "".join(
            f"BT /F1 {size} Tf {x} {y} Td ({esc(text)}) Tj ET\n" for x, y, size, text in lines
        ).encode()
        objects.append(b"<< /Length " + str(len(stream)).encode() + b" >>\nstream\n" + stream + b"endstream")
    return assemble(objects, 1)


def annotated_pdf():
    """A book carrying both kinds of yellow mark, so one import tells the two apart.

    Build 24 hides highlight *annotations* the file itself carries - what Books, Preview and most
    desktop readers write. It cannot touch a mark flattened into the page's own artwork, because
    that is just drawing, indistinguishable from the text around it. Grit turned out to be the
    second kind, which is why it could never be cleared from inside PageVault.

    Pages 2, 3 and 5 carry real /Highlight annotations, with an appearance stream so every viewer
    shows them. Page 4 carries the same yellow drawn straight into the content stream. On Build 24
    the first three should come up clean and page 4 should stay marked; page 1 says so in the book.
    """
    objects = [None, None, None]  # 1 catalog, 2 pages, 3 font

    def add(body):
        objects.append(body)
        return len(objects)

    def stream_obj(body, extra=""):
        header = f"<< {extra} /Length {len(body)} >>".encode()
        return add(header + b"\nstream\n" + body + b"\nendstream")

    objects[2] = b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"

    intro = [
        "What this book is for",
        "",
        "Two kinds of yellow mark live in this file, and they are not the same thing.",
        "",
        "Pages 2, 3 and 5 are highlighted the way Books and Preview do it: a real",
        "annotation stored alongside the page. Build 24 hides those, so those pages",
        "should look completely clean here.",
        "",
        "Page 4 is highlighted the way the Grit copy was: the yellow is painted into",
        "the page itself, with no annotation anywhere. Nothing PageVault does can",
        "reach it, so page 4 should still be marked - and that is the correct",
        "result, not a bug.",
        "",
        "So: pages 2, 3 and 5 clean, page 4 still yellow.",
        "Anything else is worth reporting.",
    ]

    page_refs = []

    # Page 1: what to expect, printed in the book itself.
    lines = [(72, 700, 20, intro[0])]
    y = 650
    for text in intro[1:]:
        if text:
            lines.append((72, y, 12, text))
        y -= 20
    body = "".join(
        f"BT /F1 {size} Tf {x} {y} Td ({esc(text)}) Tj ET\n" for x, y, size, text in lines
    ).encode()
    content = stream_obj(body)
    page_refs.append(add(
        f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {PAGE_W} {PAGE_H}] "
        f"/Resources << /Font << /F1 3 0 R >> >> /Contents {content} 0 R >>".encode()
    ))

    # Pages 2-6: text, marked as described above.
    annotated_pages = {2: [0, 1], 3: [4], 5: [2, 7]}
    flattened_page = 4
    for number in range(2, 7):
        lines = [(72, 700, 26, f"Page {number} of 6"), (72, 660, 14, "Highlight-boundary fixture")]
        rows = []
        y = 620
        for n in range(12):
            rows.append((72, y, 11, f"Line {n + 1} on page {number}. "
                                    "This sentence exists so there is something worth marking."))
            y -= 22
        lines.extend(rows)

        painted = b""
        if number == flattened_page:
            # The Grit case: yellow drawn into the page, beneath the text, the way a highlighter's
            # output looks once it has been flattened into the page content.
            for index in (3, 6):
                ly = rows[index][1]
                painted += f"q 1 1 0 rg 70 {ly - 4} 430 16 re f Q\n".encode()

        body = painted + "".join(
            f"BT /F1 {size} Tf {x} {y} Td ({esc(text)}) Tj ET\n" for x, y, size, text in lines
        ).encode()
        content = stream_obj(body)

        annots = []
        for index in annotated_pages.get(number, []):
            ly = rows[index][1]
            x0, y0, x1, y1 = 70, ly - 4, 500, ly + 12
            appearance = f"/GS0 gs 1 1 0 rg {x0} {y0} {x1 - x0} {y1 - y0} re f\n".encode()
            ap = stream_obj(appearance, extra=(
                f"/Type /XObject /Subtype /Form /BBox [{x0} {y0} {x1} {y1}] "
                f"/Resources << /ExtGState << /GS0 << /Type /ExtGState /BM /Multiply >> >> >>"
            ))
            annots.append(add(
                f"<< /Type /Annot /Subtype /Highlight /Rect [{x0} {y0} {x1} {y1}] "
                f"/QuadPoints [{x0} {y1} {x1} {y1} {x0} {y0} {x1} {y0}] "
                f"/C [1 1 0] /CA 1 /F 4 /T (Fixture) /Contents (Annotation highlight) "
                f"/AP << /N {ap} 0 R >> >>".encode()
            ))

        entry = (f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {PAGE_W} {PAGE_H}] "
                 f"/Resources << /Font << /F1 3 0 R >> >> /Contents {content} 0 R")
        if annots:
            entry += " /Annots [" + " ".join(f"{r} 0 R" for r in annots) + "]"
        entry += " >>"
        page_refs.append(add(entry.encode()))

    objects[0] = b"<< /Type /Catalog /Pages 2 0 R >>"
    objects[1] = (f"<< /Type /Pages /Kids [{' '.join(f'{r} 0 R' for r in page_refs)}] "
                  f"/Count {len(page_refs)} >>").encode()
    return assemble(objects, 1)


def scan_pdf(pages, width=1700, height=2200, quality=70):
    """Grayscale noise pages embedded as JPEG, which is roughly how a real scan behaves:
    large per-page image data that cannot be cheaply recompressed."""
    kids = " ".join(f"{3 + 2 * i} 0 R" for i in range(pages))
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        f"<< /Type /Pages /Kids [{kids}] /Count {pages} >>".encode(),
    ]
    for i in range(pages):
        image = Image.effect_noise((width, height), 48)
        buffer = io.BytesIO()
        image.save(buffer, format="JPEG", quality=quality)
        jpeg = buffer.getvalue()
        image_ref = 4 + 2 * i
        objects.append(
            f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {PAGE_W} {PAGE_H}] "
            f"/Resources << /XObject << /Im0 {image_ref} 0 R >> >> /Contents {image_ref + 1} 0 R >>".encode()
        )
        objects.append(
            f"<< /Type /XObject /Subtype /Image /Width {width} /Height {height} "
            f"/ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /DCTDecode /Length {len(jpeg)} >>".encode()
            + b"\nstream\n" + jpeg + b"\nendstream"
        )
        stream = f"q {PAGE_W} 0 0 {PAGE_H} 0 0 cm /Im0 Do Q\n".encode()
        objects.append(b"<< /Length " + str(len(stream)).encode() + b" >>\nstream\n" + stream + b"endstream")
        print(f"  scan page {i + 1}/{pages}", end="\r", flush=True)
    # Page objects reference image at 4+2i, but each page adds two objects after itself,
    # so rebuild Kids with the real page positions.
    page_numbers = [3 + 3 * i for i in range(pages)]
    objects[1] = (f"<< /Type /Pages /Kids [{' '.join(f'{n} 0 R' for n in page_numbers)}] "
                  f"/Count {pages} >>").encode()
    for index, number in enumerate(page_numbers):
        objects[number - 1] = (
            f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {PAGE_W} {PAGE_H}] "
            f"/Resources << /XObject << /Im0 {number + 1} 0 R >> >> /Contents {number + 2} 0 R >>"
        ).encode()
    print()
    return assemble(objects, 1)


def write(name, data):
    path = OUT / name
    path.write_bytes(data)
    size = path.stat().st_size
    reader = PdfReader(str(path))
    print(f"{name:34} {size / 1_048_576:8.1f} MB  {len(reader.pages):>5} pages")
    return path


print("Generating PageVault test PDFs into", OUT)

# 1. Long text-heavy book: scrolling, resume, page count, text search.
long_text = write("01-long-text-600-pages.pdf", text_pdf(600, "Long text-heavy fixture"))

# 2. Deep three-level outline: TOC hierarchy and jump-to-page.
outlined = OUT / "02-deep-outline-180-pages.pdf"
source = PdfReader(str(write("_tmp-outline-source.pdf", text_pdf(180, "Deep outline fixture"))))
writer = PdfWriter()
for page in source.pages:
    writer.add_page(page)
for part in range(3):
    part_item = writer.add_outline_item(f"Part {part + 1}", part * 60)
    for chapter in range(4):
        first = part * 60 + chapter * 15
        chapter_item = writer.add_outline_item(f"Chapter {part + 1}.{chapter + 1}", first, parent=part_item)
        for section in range(3):
            writer.add_outline_item(
                f"Section {part + 1}.{chapter + 1}.{section + 1}", first + section * 5, parent=chapter_item
            )
with open(outlined, "wb") as handle:
    writer.write(handle)
print(f"{outlined.name:34} {outlined.stat().st_size / 1_048_576:8.1f} MB  "
      f"{len(PdfReader(str(outlined)).pages):>5} pages  (3-level outline)")
(OUT / "_tmp-outline-source.pdf").unlink()

# 3. No outline at all: proves the honest "No table of contents" state.
write("03-no-outline-40-pages.pdf", text_pdf(40, "No outline fixture"))

# 4. Password protected: must fail with a clear message, not a false library entry.
protected = OUT / "05-password-protected.pdf"
source = PdfReader(str(write("_tmp-protected-source.pdf", text_pdf(12, "Encrypted fixture"))))
writer = PdfWriter()
for page in source.pages:
    writer.add_page(page)
writer.encrypt("pagevault")
with open(protected, "wb") as handle:
    writer.write(handle)
print(f"{protected.name:34} {protected.stat().st_size / 1_048_576:8.1f} MB  (password: pagevault)")
(OUT / "_tmp-protected-source.pdf").unlink()

# 5. Corrupt: truncated mid-object, so PDFKit cannot open it.
good = text_pdf(30, "Truncated fixture")
(OUT / "06-corrupt-truncated.pdf").write_bytes(good[: len(good) // 3])
print(f"{'06-corrupt-truncated.pdf':34} "
      f"{(OUT / '06-corrupt-truncated.pdf').stat().st_size / 1_048_576:8.1f} MB  (deliberately broken)")

# 6. Highlight boundary: annotation marks Build 24 hides, and flattened marks it cannot.
write("07-highlight-boundary.pdf", annotated_pdf())

# 7. Image-heavy scan-like book: the memory-pressure case.
write("04-image-heavy-scan-120-pages.pdf", scan_pdf(120))

print("\nDone. Files in", OUT)
