const $$ = (...args) => Array.from(content.document.querySelectorAll(...args));


vimfx.listen("touhou_titles", (data, callback) => {
    // const $$ = content.document.querySelectorAll;
    let title_html = [];
    $$("table.wikitable tr:nth-of-type(1) td:nth-of-type(2)").forEach((e) => {
        title_html.push(e.textContent.trim());
    });

    let title_html_transc = [];
    $$("table.wikitable tr:nth-of-type(1) td:nth-of-type(3)").forEach((e) => {
        title_html_transc.push(e.textContent.trim());
    });


    // gClipboardHelper.copyString("Put me on the clipboard, please.");

    function process_array(array) {
        const str = title_html.join("\n");
        console.log("calling callback");
        callback(str);
    }

    let final_array = [];
    final_array = final_array.concat(title_html);
    final_array.push("");
    final_array = final_array.concat(title_html_transc);

    callback(final_array.join("\n"));

    // process_array(title_html);
});


vimfx.listen("query_selector_test", (data, callback) => {
    // const $$ = content.document.querySelectorAll;
    $$("table.wikitable tr:nth-of-type(1) td:nth-of-type(2)").forEach((e) => {
        console.log(e.textContent.trim());
    });
});
