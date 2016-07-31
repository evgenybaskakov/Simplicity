//
//  SearchWebView.js
//  Simplicity
//
//  Created by Evgeny Baskakov on 2/22/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

// Based on this tutorial: http://www.icab.de/blog/2010/01/12/search-and-highlight-text-in-uiwebview/

// We're using a global variable to store the number of occurrences
var Simplicity_HighlightClass = "Simplicity_Highlight";
var Simplicity_SearchResultCount = 0;
var Simplicity_MarkedResultIndex = -1;
var Simplicity_SearchResults = [];
var Simplicity_HighlightColorText = "black";
var Simplicity_HighlightColorBackground = "lightgray";
var Simplicity_MarkColorText = "black";
var Simplicity_MarkColorBackground = "yellow";
var Simplicity_ElementNode = 1;
var Simplicity_TextNode = 3;

// helper function, recursively searches in elements and their child nodes
function Simplicity_HighlightAllOccurrencesOfStringForElement(element, keyword, matchCase) {
    if (element) {
        if (element.nodeType == Simplicity_TextNode) {
            while (true) {
                var value = element.nodeValue;  // Search for keyword in text node
                var idx = matchCase? value.indexOf(keyword) : value.toLowerCase().indexOf(keyword);
                
                if (idx < 0)
                    break;
                
                var span = document.createElement("span");
                var text = document.createTextNode(value.substr(idx,keyword.length));
                span.appendChild(text);
                span.setAttribute("class", Simplicity_HighlightClass);
                span.style.backgroundColor = Simplicity_HighlightColorBackground;
                span.style.color = Simplicity_HighlightColorText;
                text = document.createTextNode(value.substr(idx+keyword.length));
                element.deleteData(idx, value.length - idx);
                var next = element.nextSibling;
                element.parentNode.insertBefore(span, next);
                element.parentNode.insertBefore(text, next);
                element = text;
                Simplicity_SearchResultCount++;
                Simplicity_SearchResults.push(span);
            }
        } else if (element.nodeType == Simplicity_ElementNode) {
            if (element.style.display != "none" && element.nodeName.toLowerCase() != 'select') {
                for (var i=element.childNodes.length-1; i >= 0; i--) {
                    Simplicity_HighlightAllOccurrencesOfStringForElement(element.childNodes[i], keyword, matchCase);
                }
            }
        }
    }
}

// helper function, recursively removes the highlights in elements and their childs
function Simplicity_RemoveAllHighlightsForElement(element) {
    if (element) {
        if (element.nodeType == 1) {
            if (element.getAttribute("class") == Simplicity_HighlightClass) {
                var text = element.removeChild(element.firstChild);
                element.parentNode.insertBefore(text,element);
                element.parentNode.removeChild(element);
                return true;
            } else {
                var normalize = false;
                for (var i=element.childNodes.length-1; i>=0; i--) {
                    if (Simplicity_RemoveAllHighlightsForElement(element.childNodes[i])) {
                        normalize = true;
                    }
                }
                if (normalize) {
                    element.normalize();
                }
            }
        }
    }
    return false;
}

// checks whether the given element is visible within the current viewport
function isScrolledIntoView(el) {
    var elemTop = el.getBoundingClientRect().top;
    var elemBottom = el.getBoundingClientRect().bottom;
    
    var isVisible = (elemTop >= 0) && (elemBottom <= window.innerHeight);
    return isVisible;
}

// the main entry point to start the search
function Simplicity_HighlightAllOccurrencesOfString(keyword, matchCase) {
    Simplicity_RemoveAllHighlights();
    Simplicity_HighlightAllOccurrencesOfStringForElement(document.body, matchCase? keyword : keyword.toLowerCase(), matchCase);
    Simplicity_SearchResults.sort(function(a, b) {
                                      if(b.getBoundingClientRect().top != a.getBoundingClientRect().top) {
                                          return b.getBoundingClientRect().top - a.getBoundingClientRect().top;
                                      }
                                      else {
                                          return b.getBoundingClientRect().left - a.getBoundingClientRect().left;
                                      }
                                  });
}

// the main entry point to mark (with a different color) the next occurrence of the string found before
function Simplicity_MarkOccurrenceOfFoundString(index) {
    Simplicity_RemoveMarkedOccurrenceOfFoundString();

    if(index >= 0 && index < Simplicity_SearchResultCount) {
        var span = Simplicity_SearchResults[Simplicity_SearchResultCount - index - 1];
        
        span.style.backgroundColor = Simplicity_MarkColorBackground;
        span.style.color = Simplicity_MarkColorText;
        
        var rect = span.getBoundingClientRect();

        Simplicity_MarkedResultIndex = index;
        
        return rect.top;
    }
    
    return null;
}

// the main entry point to remove the previously marked occurrence of the found string
function Simplicity_RemoveMarkedOccurrenceOfFoundString() {
    var index = Simplicity_MarkedResultIndex;

    if(index >= 0 && index < Simplicity_SearchResultCount) {
        var span = Simplicity_SearchResults[Simplicity_SearchResultCount - index - 1];

        span.style.backgroundColor = Simplicity_HighlightColorBackground;
        span.style.color = Simplicity_HighlightColorText;
    }
    
    Simplicity_MarkedResultIndex = -1;
}

// the main entry point to remove the highlights
function Simplicity_RemoveAllHighlights() {
    Simplicity_SearchResultCount = 0;
    Simplicity_MarkedResultIndex = -1;
    Simplicity_SearchResults = [];

    Simplicity_RemoveAllHighlightsForElement(document.body);
}
