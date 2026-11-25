# Building and testing: the traps

What agents have learnt making pages, renders and videos, beyond what the skills in these lists say. Linked from the lists for [websites and design](web-and-design.md), [code](code.md) and [media](media.md). The core's "best guess, light checks" still holds: these are the checks worth their time, not more of them.

## Pages
- **See a page without a server.** A web server left running in the background gets stopped at a session's time limit, or refused by its safety check. Playwright can answer the page's requests from the checkout itself, so nothing needs to run beside it ([webapp-testing](../webapp-testing/SKILL.md) starts a server; this doesn't):
  ```python
  import mimetypes, pathlib
  root = pathlib.Path("site")  # the folder with index.html
  def serve(route):
      path = root / (route.request.url.split("://local/", 1)[1].split("?")[0] or "index.html")
      if path.is_file():
          route.fulfill(body=path.read_bytes(), content_type=mimetypes.guess_type(path.name)[0] or "application/octet-stream")
      else:
          route.fulfill(status=404)
  page.route("http://local/**", serve)
  page.goto("http://local/")
  ```
- **Load the page once before pushing,** in a headless browser, and read its console errors (`page.on("console", ...)` and `page.on("pageerror", ...)`). Tests that don't load that file miss a broken script, and so does `node --check`, which reads a module as a plain script: one unescaped apostrophe in a string stops the whole page.
- **Playwright's WebKit isn't Safari on an iPhone.** Motion that plays once in WebKit can restart on a real iPhone, and Safari's toolbar resizing the page as it scrolls can't be reproduced. Ask the owner to try motion on their phone. To check a short move's frames, pause the page's animations and step them (`document.getAnimations()`, each `.pause()`, then set `.currentTime`): a screen recording at 25 frames a second catches only one or two frames of a half-second move.
- **Speed:** run Lighthouse against the preview or live address (`npx lighthouse <address> --only-categories=performance`). PageSpeed Insights without a key shares one quota with everyone and often answers "Quota exceeded", and a cloud session may not be able to run Lighthouse against a server of its own.
- **CSS traps:** an IntersectionObserver on a box that's clipped shut never fires, so watch its wrapper; a reveal set to fire "above the bottom 12% of the screen" never fires for a short last item that can't scroll that high; a flex button drops the space before an inline part inside it, so give it a `gap`; a colour in any layer of a `background` shorthand but the last makes the whole line invalid.
- **Each piece on the page it's about:** customers' reviews go on the product page they review, where the site has a place for them there, not all on the home page. Keep reviews in the customers' own plain words (why they bought, how they use it, a small gripe): polished into punchlines, they read as made up.
- **Email can't be styled everywhere.** New Outlook for Windows' dark mode overrides a message's colours whatever is tried, and the "Safe Links" banner is Outlook's own. Don't spend time fighting either.

## Renders and video
- **Render into a fresh folder.** Renderers that skip files already there report "0 frames" and exit 0 when the old frames are still in the out folder, and the sheet or video is then built from the old ones. Give each changed setting a new folder, or empty it first, and check the count in the log.
- **Cutting a screen recording with ffmpeg:** screen recordings have a frame only when the screen changes, so `-ss` before `-i` at an in-point inside a still stretch jumps on to the next change. Seek a couple of seconds early, make the frame rate steady with the `fps` filter, and trim after it: `ffmpeg -ss <in-point minus 2 s> -i rec.mp4 -vf fps=30 -ss 2 -t <length> out.mp4`.

## Any build
- **One thing made in two places drifts.** When two scripts (or a page and its preview) make the same effect, each fix to one leaves the other behind. Change both together and look at them side by side, or have one use the other. And check a fix over the whole stretch it touches, not only near the point that was wrong.
- **Blender, and a 3D model with no GPU:** the [image-to-3d skill](../image-to-3d/SKILL.md).
