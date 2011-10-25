type expr = 
  | EmptyExpr
  | Literal of string
  | Range of string * string * string * string
  | Braces of expr * expr * expr
  | Regex of string
  | HostGroup of expr
  | Parens of expr
  | Union of expr * expr
  | Diff of expr * expr
  | Inter of expr * expr
  | Cluster of expr * expr
  | Admin of expr
  | GetCluster of expr
  | Filter of expr * string
  | NotFilter of expr * string
  | GetGroup of expr
  | Function of string * string
      
