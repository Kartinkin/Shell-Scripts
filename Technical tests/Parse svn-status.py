#!/usr/bin/python

import fileinput

# Columns definitions
STATUS = 0          # Says if item was added, deleted, or otherwise changed
PROPERTY_STATUS = 1 # Modifications of a file's or directory's properties
LOCKED = 2          # Is the working copy directory locked
HISTORY = 3         # Scheduled commit will contain addition-with-history
SWITCHED = 4        # Whether the item is switched or a file external
LOCK_TOKEN = 5      # Repository lock token
CONFLICT = 6        # Whether the item is the victim of a tree conflict
REV = 7             # Working-revision of the item
COMMIT = 8          # The revision in which the item last changed
USER = 9            # User who changed item
ITEM = 10           # Item name

# One-char columns
CHARS = [
    STATUS,
    PROPERTY_STATUS,
    LOCKED,
    HISTORY,
    SWITCHED, 
    LOCK_TOKEN,
    CONFLICT ]

# Very last four columns
COLUMNS = CHARS + [
    REV,
    COMMIT,
    USER,
    ITEM ]

HEADER = {
    STATUS: "Status",
    PROPERTY_STATUS: "Properties",
    LOCKED: "Locked",
    HISTORY: "History",
    SWITCHED: "Relation to a parent",
    LOCK_TOKEN: "Lock",
    CONFLICT: "Conflict",
    REV: "Revision",
    COMMIT: "Commit",
    USER: "Last writer",
    ITEM: "File name" }

# Dictionary of dictionaries for each column
# { <column name>: { <char>: <description> } } 
CHAR_TO_STR = {
    # TODO: Add all possible values
    STATUS: {
        ' ': "No modifications",
        'A': "Added",
        'C': "Conflicted",
        'D': "Deleted",
        'I': "Ignored",
        'M': "Modified" },
    PROPERTY_STATUS: {
        ' ': "No modifications" },
    LOCKED: {
        ' ': "Not locked",
        'L': "Locked" },
    HISTORY: {
        ' ': "Isn't scheduled with commit",
        '+': "Scheduled with commit" },
    SWITCHED: {
        ' ': "Child"},
    LOCK_TOKEN: {
        ' ': "No lock" },
    CONFLICT: {
        ' ': "No conflict" },
    # I look up columns the same way and
    # the follows empty dictionaries are important 
    REV: {},
    COMMIT: {},
    USER: {},
    ITEM: {} }

COLUMN_DIVIDER = "| " 
HEADER_UNDERLINE = "-"
        
class TableRow:
    """
    Class represents row in a table.
    """
    def __init__(self):
        self._cells = list(' ' * len(COLUMNS))
        
    def getCell(self, cell):
        if cell in COLUMNS:
            # Get cell mapping from dictionary
            # If there is no key in dictionary, return cell itself
            return CHAR_TO_STR[cell].get(self._cells[cell], self._cells[cell])
        else:
            return None

    def setCell(self, cell, value):
        if cell in COLUMNS:
            self._cells[cell] = value
    
    def formattedLine(self, columns, widthOfCells):
        output = COLUMN_DIVIDER
        for cell in columns:
            output += self.getCell(cell).ljust(widthOfCells[cell])
            output += COLUMN_DIVIDER
        return output
        
    def __str__(self):
        divider = ", "
        output = "("
        for cell in COLUMNS:
            output += self.getCell(cell) + divider
        return output.rstrip(divider) + ")"
    
class SVNRow(TableRow):
    """
    Add read method specific to "svn status -uv"
    """
    def __init__(self, input):
        TableRow.__init__(self)
        for char in CHARS:
            self._cells[char] = input[char]
        self._cells[REV] = input[10:18].lstrip()
        self._cells[COMMIT] = input[19:27].lstrip()
        self._cells[USER] = input[28:41].strip()
        self._cells[ITEM] = input[41:]     
    
class SVNTable:
    """
    Class represents list of SVNRow
    It loads rows and prints they out
    """
    def __init__(self):
        self._rows = []
    
    def readItems(self, input):
        # Add row into the table line by line
        for line in input:
            # Check for odd line
            if line[CONFLICT] != '>':
                self._rows.append(SVNRow(line.rstrip()))
            else:
                # Nature of conflict found
                # Add it to previous row into conflict cell
                if len(self._rows) > 0:
                    self._rows[-1].setCell(CONFLICT, line[CONFLICT + 1:].strip())
            
    def printTable(self, columns):
        # Remove unknown columns
        columns = filter(lambda col: col in COLUMNS, columns)
        # Create array for all column numbers
        widthOfColumn = range(max(columns) + 1)
        
        # Calculate width of columns
        for col in columns:
            widthOfColumn[col] = reduce(lambda i, row: max(i, len(row.getCell(col))), self._rows, len(HEADER[col])) + 1

        # Print header
        header = COLUMN_DIVIDER
        for col in columns:
            header += HEADER[col].ljust(widthOfColumn[col]) + COLUMN_DIVIDER
        print header
        if HEADER_UNDERLINE is not None:
            print HEADER_UNDERLINE * (len(header) - 1)
        
        # Print rows 
        for row in self._rows:
            print row.formattedLine(columns, widthOfColumn)
            
table = SVNTable()
table.readItems(fileinput.input())
table.printTable(COLUMNS)
