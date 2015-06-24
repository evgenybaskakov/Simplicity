var editor, commands;

function Simplicity_EditorStart() {
    console.log("Simplicity_EditorStart");

    try {
        editor = new wysihtml5.Editor("editor-container", {
                                          parserRules:    wysihtml5ParserRules,
                                          useLineBreaks:  false
                                          });

        commands = new wysihtml5.Commands(editor);
    } catch(e) {
        return "Error " + e.toString() + "\nStack: " + e.stack;
    }
    return "Success";
}

function Simplicity_EditorToggleBold() {
    console.log("Simplicity_EditorToggleBold");

    try {
        commands.exec("bold");
    } catch(e) {
        return "Error " + e.toString() + "\nStack: " + e.stack;
    }
    return "Success";
}

function Simplicity_EditorToggleItalic() {
    console.log("Simplicity_EditorToggleBold");

    try {
        commands.exec("italic");
    } catch(e) {
        return "Error " + e.toString() + "\nStack: " + e.stack;
    }
    return "Success";
}

function Simplicity_EditorToggleUnderline() {
    console.log("Simplicity_EditorTogglUnderline");
    
    try {
        commands.exec("underline");
    } catch(e) {
        return "Error " + e.toString() + "\nStack: " + e.stack;
    }
    return "Success";
}
