# Example vault files

Baroque reads Markdown from your Obsidian vault on GitHub. These are the shapes it understands.

- `Daily Brief/Today.md`: the task source (the Today widget and the Brief page). Open tasks are Obsidian Tasks lines, `- [ ] #todo …`, with an optional priority emoji and `📅 YYYY-MM-DD`; everything else in the note is shown on the Brief page but isn't a task.
- `Quotes.md`: the quotes. A blockquote with an author line starting with a dash, a bullet `- "text" — Author`, or a line that opens with a quotation mark, `“text” - Author`. Headings and other prose are ignored.

Both paths can be changed in the app.
