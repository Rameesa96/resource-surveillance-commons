import * as spn from "../sqlpage-notebook.ts";

export class ShellSqlPages extends spn.TypicalSqlPageNotebook {
  defaultShell() {
    return {
      component: "shell",
      title: "Resource Surveillance State Database (RSSD)",
      icon: "database",
      layout: "fluid",
      fixed_top_menu: true,
      link: "/",
      menu_item: [
        { link: "/", title: "Home" },
        {
          title: "Console",
          submenu: [
            { link: "blog.sql", title: "Blog" },
            { link: "//github.com/lovasoa/sqlpage", title: "Github" },
          ],
        },
      ],
      javascript: [
        "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11/build/highlight.min.js",
        "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11/build/languages/sql.min.js",
        "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11/build/languages/handlebars.min.js",
        "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11/build/languages/json.min.js",
      ],
      footer: `Resource Surveillance Web UI`,
    };
  }

  @spn.shell({ eliminate: true })
  "shell/shell.json"() {
    return this.SQL`
      ${JSON.stringify(this.defaultShell(), undefined, "  ")}
    `;
  }

  @spn.shell({ eliminate: true })
  "shell/shell.sql"() {
    const literal = (value: unknown) =>
      typeof value === "number"
        ? value
        : value
        ? this.emitCtx.sqlTextEmitOptions.quotedLiteral(value)[1]
        : "NULL";
    const handlers = {
      DEFAULT: (key: string, value: unknown) => `${literal(value)} AS ${key}`,
      menu_item: (key: string, items: Record<string, unknown>[]) =>
        items.map((item) => `${literal(JSON.stringify(item))} AS ${key}`),
      javascript: (key: string, scripts: string[]) =>
        scripts.map((s) => `${literal(s)} AS ${key}`),
    };
    const shell = this.defaultShell();
    const sqlSelectExpr = Object.entries(shell).flatMap(([k, v]) => {
      switch (k) {
        case "menu_item":
          return handlers.menu_item(k, v as Record<string, unknown>[]);
        case "javascript":
          return handlers.javascript(k, v as string[]);
        default:
          return handlers.DEFAULT(k, v);
      }
    });
    return this.SQL`
      SELECT ${sqlSelectExpr.join(",\n       ")};
    `;
  }
}
