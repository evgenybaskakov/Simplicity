var editor;

function Simplicity_EditorStart() {
    try {
        editor = new Quill('#editor-container', {});
    } catch(e) {
        return "Error " + e.toString();
    }
    editor.on('selection-change', function(range) {
                console.log('selection-change', range)
              });
    editor.on('text-change', function(delta, source) {
                console.log('text-change', delta, source)
              });
    return "Success";
}

function Simplicity_EditorLoadTemplate() {
    editor.setContents([
                       { insert: 'Hello ' },
                       { insert: 'World!', attributes: { bold: true } },
                       { insert: '\n' }
                       ]);
}
