marked.setOptions({
    gfm: true,
    breaks: false
});

window.renderMarkdown = function(base64) {
    var md = decodeURIComponent(escape(atob(base64)));
    var html = marked.parse(md);
    var content = document.getElementById('content');
    content.innerHTML = html;
    content.classList.remove('empty');
    window.scrollTo(0, 0);
};
