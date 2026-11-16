// The tabs of the Form plugin (forms/fields/tabs) as tabs for the keyboard and screen readers: a tab list whose tabs are links to
// their panels, the arrow keys move between them, Space or Enter opens one. The Form plugin's own script still switches the panels.
document.querySelectorAll('.form-tabs .tabs-nav').forEach((nav) => {
    const tabs = [...nav.querySelectorAll('[data-tabid]')];
    const sync = () => tabs.forEach((tab) => {
        const active = tab.classList.contains('active');
        tab.setAttribute('aria-selected', String(active));
        tab.tabIndex = active ? 0 : -1;
    });
    nav.setAttribute('role', 'tablist');
    tabs.forEach((tab, index) => {
        const id = tab.dataset.tabid;
        tab.id = `${id}-tab`;
        tab.href = `#${id}`;
        tab.setAttribute('role', 'tab');
        tab.setAttribute('aria-controls', id);
        document.getElementById(id)?.setAttribute('role', 'tabpanel');
        document.getElementById(id)?.setAttribute('aria-labelledby', tab.id);
        tab.addEventListener('click', (event) => {
            event.preventDefault();
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
