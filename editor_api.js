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


function Simplicity_EditorToggleBullets() {
    console.log("Simplicity_EditorToggleBullets");
    
    try {
        commands.exec("insertUnorderedList");
    } catch(e) {
        return "Error " + e.toString() + "\nStack: " + e.stack;
    }
    return "Success";
}

function Simplicity_EditorToggleNumbering() {
    console.log("Simplicity_EditorToggleNumbering");
    
    try {
        commands.exec("insertOrderedList");
    } catch(e) {
        return "Error " + e.toString() + "\nStack: " + e.stack;
    }
    return "Success";
}

function Simplicity_EditorToggleQuote() {
    console.log("Simplicity_EditorToggleQuote");
    
    try {
        // see https://css-tricks.com/examples/Blockquotes/
        commands.exec("TODO");
    } catch(e) {
        return "Error " + e.toString() + "\nStack: " + e.stack;
    }
    return "Success";
}

function Simplicity_EditorShiftLeft() {
    console.log("Simplicity_EditorShiftLeft");
    
    try {
        commands.exec("TODO");
    } catch(e) {
        return "Error " + e.toString() + "\nStack: " + e.stack;
    }
    return "Success";
}

function Simplicity_EditorShiftRight() {
    console.log("Simplicity_EditorShiftRight");
    
    try {
        commands.exec("TODO");
    } catch(e) {
        return "Error " + e.toString() + "\nStack: " + e.stack;
    }
    return "Success";
}
