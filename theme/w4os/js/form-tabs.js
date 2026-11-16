// The tabs of the Form plugin (forms/fields/tabs) as tabs for the keyboard and screen readers: a tab list whose tabs are links to
// their panels, the arrow keys move between them, Space or Enter opens one. The Form plugin's own script still switches the panels.
// The tab open is in the address (#interests, the name of the tab), for a reload, and in the address the form posts to: the page
// after Save (the server's redirect keeps it) opens it again.
document.querySelectorAll('.form-tabs .tabs-nav').forEach((nav) => {
    const tabs = [...nav.querySelectorAll('[data-tabid]')];
    const form = nav.closest('form');
    const name = (tab) => (tab.dataset.scope || '').split('.').pop().replace(/_/g, '-');
    const remember = (tab) => {
        history.replaceState(null, '', `#${name(tab)}`);
        form && (form.action = `${form.action.split('#')[0]}#${name(tab)}`);
    };
    const sync = () => tabs.forEach((tab) => {
        const active = tab.classList.contains('active');
        tab.setAttribute('aria-selected', String(active));
        tab.tabIndex = active ? 0 : -1;
    });
    nav.setAttribute('role', 'tablist');
    tabs.forEach((tab, index) => {
        const id = tab.dataset.tabid;
        tab.id = `${id}-tab`;
        tab.href = `#${name(tab)}`;
        tab.setAttribute('role', 'tab');
        tab.setAttribute('aria-controls', id);
        document.getElementById(id)?.setAttribute('role', 'tabpanel');
        document.getElementById(id)?.setAttribute('aria-labelledby', tab.id);
        tab.addEventListener('click', (event) => {
            event.preventDefault();
            remember(tab);
            setTimeout(sync);
        });
        tab.addEventListener('keydown', (event) => {
            const step = { ArrowRight: 1, ArrowLeft: -1 }[event.key];
            if (step) {
                const next = tabs[(index + step + tabs.length) % tabs.length];
                next.click();
                next.focus();
            } else if (event.key === ' ') {
                tab.click();
            } else {
                return;
            }
            event.preventDefault();
        });
    });
    sync();
    // The tab the address names, once the Form plugin's script listens
    const asked = () => tabs.find((tab) => `#${name(tab)}` === location.hash);
    asked() && document.addEventListener('DOMContentLoaded', () => asked().click());
    // A link to a tab of the page (#picks) opens it
    window.addEventListener('hashchange', () => asked()?.click());
});

// The text areas that grow with their text (class w4os-autogrow), for the browsers without CSS field-sizing: on load, as they
// are typed in, and when the tab they are in opens
if (!(window.CSS && CSS.supports('field-sizing', 'content'))) {
    const areas = [...document.querySelectorAll('textarea.w4os-autogrow')];
    const grow = (area) => {
        if (area.offsetParent === null) {
            return;
        }
        area.style.height = 'auto';
        area.style.height = `${area.scrollHeight + area.offsetHeight - area.clientHeight}px`;
    };
    areas.forEach((area) => {
        area.addEventListener('input', () => grow(area));
        grow(area);
    });
    document.addEventListener('click', (event) => event.target.closest?.('[data-tabid]') && setTimeout(() => areas.forEach(grow)));
}
