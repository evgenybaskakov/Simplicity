var editor, commands;

function Simplicity_EditorStart() {
    try {
        editor = new wysihtml5.Editor("editor-container", {
                                          parserRules:    wysihtml5ParserRules,
                                          useLineBreaks:  false
                                          });

        commands = new wysihtml5.Commands(editor);
    } catch(e) {
        return "Error " + e.toString();
    }
    return "Success";
}

function Simplicity_EditorToggleBold() {
    try {
        commands.exec("bold");
    } catch(e) {
        return "Error " + e.toString();
    }
    return "Success";
}

function Simplicity_EditorToggleItalic() {
    try {
        commands.exec("insertImage", "http://i.telegraph.co.uk/multimedia/archive/03204/Jennifer-in-Paradi_3204219n.jpg");
        commands.exec("bold");
    } catch(e) {
        return "Error " + e.toString();
    }
    return "Success";
}
