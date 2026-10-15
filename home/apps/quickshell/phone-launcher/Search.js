.pragma library

function normalize(text) {
    return String(text || "").normalize("NFKD").replace(/[\u0300-\u036f]/g, "")
        .toLowerCase().replace(/[_\-.]+/g, " ").replace(/\s+/g, " ").trim();
}
function fuzzyScore(text, query) {
    let position = -1, gaps = 0;
    for (const character of query.replace(/\s/g, "")) {
        const next = text.indexOf(character, position + 1);
        if (next < 0) return -1;
        gaps += next - position - 1;
        position = next;
    }
    return gaps;
}
function rank(applications, query) {
    const needle = normalize(query), terms = needle.split(" ");
    return applications.filter(app => !app.noDisplay).map(app => {
        const name = normalize(app.name);
        const words = name.split(" ");
        const metadata = normalize([app.genericName, ...(app.keywords || [])].join(" "));
        let tier = -1, score = 0;
        if (!needle || name === needle) tier = 0;
        else if (name.startsWith(needle)) tier = 1;
        else if (terms.every(term => words.some(word => word.startsWith(term)))) tier = 2;
        else if (terms.every(term => name.includes(term))) tier = 3;
        else if (terms.every(term => (name + " " + metadata).includes(term))) tier = 4;
        else { score = fuzzyScore(name, needle); if (score >= 0) tier = 5; }
        return {app, name, tier, score};
    }).filter(hit => hit.tier >= 0).sort((a, b) => a.tier - b.tier || a.score - b.score
        || a.name.localeCompare(b.name) || String(a.app.id || "").localeCompare(String(b.app.id || "")))
        .map(hit => hit.app);
}
