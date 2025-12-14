const fs = require('fs');
const path = require('path');

describe('Roadmap Documentation', () => {
  let content;
  beforeAll(() => {
    const filePath = path.join(__dirname, 'roadmap.md');
    content = fs.readFileSync(filePath, 'utf8');
  });

  it('has the main title', () => {
    expect(content).toMatch(/^# EasyCamper – Roadmap & Checklist/);
  });

  it('includes section 6: Database Camper – MEDIA', () => {
    expect(content).toMatch(/## 6\. Database Camper – MEDIA/);
    expect(content).toMatch(/Creare un database con i modelli di camper van/);
    expect(content).toMatch(/Valutare l'uso di API esterne/);
  });

  it('includes section 7: Prezzi Carburante – MEDIA', () => {
    expect(content).toMatch(/## 7\. Prezzi Carburante – MEDIA/);
    expect(content).toMatch(/Sviluppare `fuelService\.js`/);
    expect(content).toMatch(/Notifiche push per avvisi sui prezzi/);
    expect(content).toMatch(/Visualizzare i prezzi del carburante lungo il percorso/);
  });

  it('includes section 8: UX Premium – MEDIA', () => {
    expect(content).toMatch(/## 8\. UX Premium – MEDIA/);
    expect(content).toMatch(/Live Activities \/ Widgets/);
    expect(content).toMatch(/Wizard “Aggiungi spot”/);
    expect(content).toMatch(/AI tagging foto/);
  });

  it('contains the Milestones Gantt chart', () => {
    expect(content).toMatch(/```mermaid[\s\S]*gantt[\s\S]*```/);
  });
});