struct = {
    name = "messageStruct",
    fields = {
      {name = "timeout", type = "int"},
      {name = "node", type = "int"},
      {name = "type", type = "string"},
      {name = "value", type = "string"}
    }
  }

  interface = {
   name = "minhaInt",
   methods = {
     StartTest1 ={
       resulttype = "void",
       args = {
         {direction = "in", type = "int"}
       }
     },
     SendMessage = {
       resulttype = "string",
       args = {
         {direction = "in", type = "messageStruct"}
       }
     },
     InitializeNode = {
       resulttype = "void",
       args = {
         {direction = "in", type = "int"}
       }
     },
     complex_foo = {
       resulttype = "double",
       args = {
         {direction = "in", type = "double"},
         {direction = "in", type = "string"},
         {direction = "in", type = "minhaStruct"},
         {direction = "inout", type = "int"}
       }
     },
     boo = {
       resulttype = "void",
       args = {
         {direction = "inout", type = "double"},
       }
     },
     boo2 = {
       resulttype = "void",
       args = {
         {direction = "inout", type = "double"},
       }
     },
     dummy = {
       resulttype = "double",
       args = {
         {direction = "in", type = "double"},
       }
     },
     dummy2 = {
       resulttype = "double",
       args = {
         {direction = "in", type = "double"},
       }
     },
     easy = {
       resulttype = "string",
       args = {
         {direction = "in", type = "string"},
       }
     },
     call_yourself = {
       resulttype = "int",
       args = {
         {direction = "in", type = "int"},
         {direction = "in", type = "int"},
       }
     },
     simple_f1 = {
       resulttype = "int",
       args = {
         {direction = "in", type = "int"},
       }
     },
     simple_f2 = {
       resulttype = "int",
       args = {
         {direction = "in", type = "int"},
       }
     }
   }
  }
  