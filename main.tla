----------------------- MODULE main -------------------------
EXTENDS Naturals, TLC, Sequences

(*
--algorithm ControllerSim {
    variables 
        wfStatus="pending", 
        nodeStatus="pending", 
        podStatus="pending", 
        containerStatus="pending", 
        taskResultSet=FALSE, 
        taskResultExists=FALSE, 
        createdPod=FALSE,
        podExists=FALSE,  \* Pod exists in cluster but controller may not see it yet
        hasFinalizer=FALSE,
        taskResultContent="",
        reconcileTriggered=FALSE,
        networkUp=TRUE,
        apiServerReachable=TRUE,
        readyNextNodeCreation=FALSE;
    
    procedure assessNodeStatus() {
        start: 
            \* Controller always has cached state - reads always work
            if (taskResultSet) {
                \* Task result takes priority for node status determination
                if (taskResultContent = "success") {
                    nodeStatus := "succeeded";
                } else if (taskResultContent = "failure") {
                    nodeStatus := "failed";
                } else {
                    nodeStatus := "error";
                };
            } else if (podStatus = "failed") {
                \* Fallback to pod status if no task result
                nodeStatus := "failed";
            } else if (podStatus = "succeeded") {
                nodeStatus := "succeeded";
            };
            \* Note: podStatus = "evicted" is NOT handled - it's a ghost state
            \* Controller cannot determine what to do with evicted pods
            
            \* Set readyNextNodeCreation when pod is in a final state
            \* Exclude "evicted" since we cannot determine completion status
            if (podStatus \in {"succeeded", "failed"}) {
                readyNextNodeCreation := TRUE;
                \* Assert the inductive property - this should fail if race condition exists
                assert (readyNextNodeCreation => taskResultExists);
            };
            return;
    };
    
    procedure updateWorkflowStatus() {
        start: 
            \* BUG: Workflow status only updates when task result exists
            \* This causes infinite reconciliation when pod fails but no task result is created
            if (apiServerReachable /\ taskResultSet) {
                if (nodeStatus = "succeeded") {
                    wfStatus := "succeeded";
                } else if (nodeStatus = "failed") {
                    wfStatus := "failed";
                } else if (nodeStatus = "error") {
                    wfStatus := "error";
                };
            };
            \* If no task result exists, workflow status never updates (BUG!)
            return;
    };
    
    procedure processPodCleanup() {
        start: 
            \* Finalizer removal requires API write access
            if (apiServerReachable) {
                if (nodeStatus \in {"succeeded", "failed", "error"} /\ hasFinalizer) {
                    hasFinalizer := FALSE;
                };
            };
            return;
    };
    
    procedure createPod() {
        start:
            \* Pod creation requires API write access  
            if (apiServerReachable) {
                if (~createdPod /\ nodeStatus = "pending") {
                    \* Controller submits pod to API server - this is atomic
                    createdPod := TRUE;
                    podExists := TRUE;  \* Pod now exists in cluster
                    hasFinalizer := TRUE;
                    \* Controller hasn't observed the pod status yet - happens separately
                };
            };
            return;
    };
    
     process (NetworkSimulator="net") {
        start: while(TRUE) {
            n0: either {
                \* Simulate API server becoming unreachable
                if (apiServerReachable) {
                    apiServerReachable := FALSE;
                };
            } or {
                \* Simulate API server recovery
                if (~apiServerReachable) {
                    apiServerReachable := TRUE;
                };
            } or skip;
        };
        done: assert(TRUE);
     }
    
     process (Kubernetes="k8s") {
        start: while(TRUE) {
            \* Pod lifecycle and task result creation
            \* Cache gets updated when API server is reachable
            n0: if (apiServerReachable) {
                either {
                    \* Controller first observes the pod - non-atomic with creation
                    if(podExists /\ podStatus = "pending" /\ containerStatus = "pending") {
                        \* Controller cache gets updated with initial pod status
                        podStatus := "pending";
                        containerStatus := "pending";
                    };
                } or {
                    \* Pod transitions to running - kubelet starts wait container
                    if(podExists /\ podStatus = "pending") {
                        podStatus := "running";
                        containerStatus := "running";
                    };
                } or {
                    \* Wait container lifecycle - does work AND writes task results
                    if(podExists /\ podStatus = "running" /\ containerStatus = "running") {
                        either {
                            \* Wait container succeeds - does work and writes task result
                            containerStatus := "completed";
                            podStatus := "succeeded";
                        } or {
                            \* Wait container fails - work lost, no task result written
                            containerStatus := "failed";
                            podStatus := "failed";
                        } or {
                            \* Wait container evicted - critical race condition!
                            \* Container may have done work but gets killed before writing task result
                            \* Ghost state: we cannot determine if work completed or not
                            containerStatus := "evicted";
                            podStatus := "evicted";
                        };
                    };
                };
            };
            
            n_1: if (apiServerReachable) {
                \* Task result creation - only when wait container completes successfully
                if (containerStatus = "completed" /\ ~taskResultExists) {
                    either {
                        \* Wait container successfully writes task result
                        taskResultExists := TRUE;
                        either {
                            taskResultContent := "success";
                        } or {
                            taskResultContent := "failure";
                        } or {
                            taskResultContent := "error";
                        };
                    } or {
                        \* Wait container API call fails - race condition!
                        skip;
                    };
                };
                
                \* Controller observes task results
                if(taskResultExists /\ ~taskResultSet) {
                    taskResultSet := TRUE;
                    reconcileTriggered := TRUE;
                };
            };
            
            n_2: if (apiServerReachable) {
                either {
                    if(taskResultExists /\ taskResultSet) { 
                        taskResultExists := FALSE;
                    };
                } or skip;
            };
        };
        done: assert(TRUE);
     }
     

     process (PodCleanupController="cleanup") {
        start: while(TRUE) {
            \* Pod cleanup controller runs independently
            \* Watches for pods with finalizers that need cleanup
            cleanup0: if (apiServerReachable) {
                \* Check if pod is ready for cleanup based on node status
                if (nodeStatus \in {"succeeded", "failed", "error"} /\ hasFinalizer) {
                    call processPodCleanup();
                };
            };
        };
        done: assert(TRUE);
     }

     process (Controller="wf") {
        start: while(TRUE) {
            \* Main workflow controller reconciliation
            \* 1. First reconcile on task results  
            call assessNodeStatus();
            
            step2: \* 2. Then perform pod reconciliation (create if needed)
            call createPod();
            
            step3: \* 3. Then update workflow status
            call updateWorkflowStatus();
            
            assess: {
                reconcileTriggered := FALSE;
            };
        };
        done: assert(TRUE);
     }

};

*)
\* BEGIN TRANSLATION
\* Label start of procedure assessNodeStatus at line 25 col 13 changed to start_
\* Label start of procedure updateWorkflowStatus at line 54 col 13 changed to start_u
\* Label start of procedure processPodCleanup at line 70 col 13 changed to start_p
\* Label start of procedure createPod at line 81 col 13 changed to start_c
\* Label start of process NetworkSimulator at line 94 col 16 changed to start_N
\* Label n0 of process NetworkSimulator at line 95 col 17 changed to n0_
\* Label done of process NetworkSimulator at line 107 col 15 changed to done_
\* Label start of process Kubernetes at line 111 col 16 changed to start_K
\* Label done of process Kubernetes at line 183 col 15 changed to done_K
\* Label start of process PodCleanupController at line 188 col 16 changed to start_P
\* Label done of process PodCleanupController at line 198 col 15 changed to done_P
VARIABLES pc, wfStatus, nodeStatus, podStatus, containerStatus, taskResultSet, 
          taskResultExists, createdPod, podExists, hasFinalizer, 
          taskResultContent, reconcileTriggered, networkUp, 
          apiServerReachable, readyNextNodeCreation, stack

vars == << pc, wfStatus, nodeStatus, podStatus, containerStatus, 
           taskResultSet, taskResultExists, createdPod, podExists, 
           hasFinalizer, taskResultContent, reconcileTriggered, networkUp, 
           apiServerReachable, readyNextNodeCreation, stack >>

ProcSet == {"net"} \cup {"k8s"} \cup {"cleanup"} \cup {"wf"}

Init == (* Global variables *)
        /\ wfStatus = "pending"
        /\ nodeStatus = "pending"
        /\ podStatus = "pending"
        /\ containerStatus = "pending"
        /\ taskResultSet = FALSE
        /\ taskResultExists = FALSE
        /\ createdPod = FALSE
        /\ podExists = FALSE
        /\ hasFinalizer = FALSE
        /\ taskResultContent = ""
        /\ reconcileTriggered = FALSE
        /\ networkUp = TRUE
        /\ apiServerReachable = TRUE
        /\ readyNextNodeCreation = FALSE
        /\ stack = [self \in ProcSet |-> << >>]
        /\ pc = [self \in ProcSet |-> CASE self = "net" -> "start_N"
                                        [] self = "k8s" -> "start_K"
                                        [] self = "cleanup" -> "start_P"
                                        [] self = "wf" -> "start"]

start_(self) == /\ pc[self] = "start_"
                /\ IF taskResultSet
                      THEN /\ IF taskResultContent = "success"
                                 THEN /\ nodeStatus' = "succeeded"
                                 ELSE /\ IF taskResultContent = "failure"
                                            THEN /\ nodeStatus' = "failed"
                                            ELSE /\ nodeStatus' = "error"
                      ELSE /\ IF podStatus = "failed"
                                 THEN /\ nodeStatus' = "failed"
                                 ELSE /\ IF podStatus = "succeeded"
                                            THEN /\ nodeStatus' = "succeeded"
                                            ELSE /\ TRUE
                                                 /\ UNCHANGED nodeStatus
                /\ IF podStatus \in {"succeeded", "failed"}
                      THEN /\ readyNextNodeCreation' = TRUE
                           /\ Assert((readyNextNodeCreation' => taskResultExists), 
                                     "Failure of assertion at line 45, column 17.")
                      ELSE /\ TRUE
                           /\ UNCHANGED readyNextNodeCreation
                /\ pc' = [pc EXCEPT ![self] = Head(stack[self]).pc]
                /\ stack' = [stack EXCEPT ![self] = Tail(stack[self])]
                /\ UNCHANGED << wfStatus, podStatus, containerStatus, 
                                taskResultSet, taskResultExists, createdPod, 
                                podExists, hasFinalizer, taskResultContent, 
                                reconcileTriggered, networkUp, 
                                apiServerReachable >>

assessNodeStatus(self) == start_(self)

start_u(self) == /\ pc[self] = "start_u"
                 /\ IF apiServerReachable /\ taskResultSet
                       THEN /\ IF nodeStatus = "succeeded"
                                  THEN /\ wfStatus' = "succeeded"
                                  ELSE /\ IF nodeStatus = "failed"
                                             THEN /\ wfStatus' = "failed"
                                             ELSE /\ IF nodeStatus = "error"
                                                        THEN /\ wfStatus' = "error"
                                                        ELSE /\ TRUE
                                                             /\ UNCHANGED wfStatus
                       ELSE /\ TRUE
                            /\ UNCHANGED wfStatus
                 /\ pc' = [pc EXCEPT ![self] = Head(stack[self]).pc]
                 /\ stack' = [stack EXCEPT ![self] = Tail(stack[self])]
                 /\ UNCHANGED << nodeStatus, podStatus, containerStatus, 
                                 taskResultSet, taskResultExists, createdPod, 
                                 podExists, hasFinalizer, taskResultContent, 
                                 reconcileTriggered, networkUp, 
                                 apiServerReachable, readyNextNodeCreation >>

updateWorkflowStatus(self) == start_u(self)

start_p(self) == /\ pc[self] = "start_p"
                 /\ IF apiServerReachable
                       THEN /\ IF nodeStatus \in {"succeeded", "failed", "error"} /\ hasFinalizer
                                  THEN /\ hasFinalizer' = FALSE
                                  ELSE /\ TRUE
                                       /\ UNCHANGED hasFinalizer
                       ELSE /\ TRUE
                            /\ UNCHANGED hasFinalizer
                 /\ pc' = [pc EXCEPT ![self] = Head(stack[self]).pc]
                 /\ stack' = [stack EXCEPT ![self] = Tail(stack[self])]
                 /\ UNCHANGED << wfStatus, nodeStatus, podStatus, 
                                 containerStatus, taskResultSet, 
                                 taskResultExists, createdPod, podExists, 
                                 taskResultContent, reconcileTriggered, 
                                 networkUp, apiServerReachable, 
                                 readyNextNodeCreation >>

processPodCleanup(self) == start_p(self)

start_c(self) == /\ pc[self] = "start_c"
                 /\ IF apiServerReachable
                       THEN /\ IF ~createdPod /\ nodeStatus = "pending"
                                  THEN /\ createdPod' = TRUE
                                       /\ podExists' = TRUE
                                       /\ hasFinalizer' = TRUE
                                  ELSE /\ TRUE
                                       /\ UNCHANGED << createdPod, podExists, 
                                                       hasFinalizer >>
                       ELSE /\ TRUE
                            /\ UNCHANGED << createdPod, podExists, 
                                            hasFinalizer >>
                 /\ pc' = [pc EXCEPT ![self] = Head(stack[self]).pc]
                 /\ stack' = [stack EXCEPT ![self] = Tail(stack[self])]
                 /\ UNCHANGED << wfStatus, nodeStatus, podStatus, 
                                 containerStatus, taskResultSet, 
                                 taskResultExists, taskResultContent, 
                                 reconcileTriggered, networkUp, 
                                 apiServerReachable, readyNextNodeCreation >>

createPod(self) == start_c(self)

start_N == /\ pc["net"] = "start_N"
           /\ pc' = [pc EXCEPT !["net"] = "n0_"]
           /\ UNCHANGED << wfStatus, nodeStatus, podStatus, containerStatus, 
                           taskResultSet, taskResultExists, createdPod, 
                           podExists, hasFinalizer, taskResultContent, 
                           reconcileTriggered, networkUp, apiServerReachable, 
                           readyNextNodeCreation, stack >>

n0_ == /\ pc["net"] = "n0_"
       /\ \/ /\ IF apiServerReachable
                   THEN /\ apiServerReachable' = FALSE
                   ELSE /\ TRUE
                        /\ UNCHANGED apiServerReachable
          \/ /\ IF ~apiServerReachable
                   THEN /\ apiServerReachable' = TRUE
                   ELSE /\ TRUE
                        /\ UNCHANGED apiServerReachable
          \/ /\ TRUE
             /\ UNCHANGED apiServerReachable
       /\ pc' = [pc EXCEPT !["net"] = "start_N"]
       /\ UNCHANGED << wfStatus, nodeStatus, podStatus, containerStatus, 
                       taskResultSet, taskResultExists, createdPod, podExists, 
                       hasFinalizer, taskResultContent, reconcileTriggered, 
                       networkUp, readyNextNodeCreation, stack >>

done_ == /\ pc["net"] = "done_"
         /\ Assert((TRUE), "Failure of assertion at line 107, column 15.")
         /\ pc' = [pc EXCEPT !["net"] = "Done"]
         /\ UNCHANGED << wfStatus, nodeStatus, podStatus, containerStatus, 
                         taskResultSet, taskResultExists, createdPod, 
                         podExists, hasFinalizer, taskResultContent, 
                         reconcileTriggered, networkUp, apiServerReachable, 
                         readyNextNodeCreation, stack >>

NetworkSimulator == start_N \/ n0_ \/ done_

start_K == /\ pc["k8s"] = "start_K"
           /\ pc' = [pc EXCEPT !["k8s"] = "n0"]
           /\ UNCHANGED << wfStatus, nodeStatus, podStatus, containerStatus, 
                           taskResultSet, taskResultExists, createdPod, 
                           podExists, hasFinalizer, taskResultContent, 
                           reconcileTriggered, networkUp, apiServerReachable, 
                           readyNextNodeCreation, stack >>

n0 == /\ pc["k8s"] = "n0"
      /\ IF apiServerReachable
            THEN /\ \/ /\ IF podExists /\ podStatus = "pending" /\ containerStatus = "pending"
                             THEN /\ podStatus' = "pending"
                                  /\ containerStatus' = "pending"
                             ELSE /\ TRUE
                                  /\ UNCHANGED << podStatus, containerStatus >>
                    \/ /\ IF podExists /\ podStatus = "pending"
                             THEN /\ podStatus' = "running"
                                  /\ containerStatus' = "running"
                             ELSE /\ TRUE
                                  /\ UNCHANGED << podStatus, containerStatus >>
                    \/ /\ IF podExists /\ podStatus = "running" /\ containerStatus = "running"
                             THEN /\ \/ /\ containerStatus' = "completed"
                                        /\ podStatus' = "succeeded"
                                     \/ /\ containerStatus' = "failed"
                                        /\ podStatus' = "failed"
                                     \/ /\ containerStatus' = "evicted"
                                        /\ podStatus' = "failed"
                             ELSE /\ TRUE
                                  /\ UNCHANGED << podStatus, containerStatus >>
            ELSE /\ TRUE
                 /\ UNCHANGED << podStatus, containerStatus >>
      /\ pc' = [pc EXCEPT !["k8s"] = "n_1"]
      /\ UNCHANGED << wfStatus, nodeStatus, taskResultSet, taskResultExists, 
                      createdPod, podExists, hasFinalizer, taskResultContent, 
                      reconcileTriggered, networkUp, apiServerReachable, 
                      readyNextNodeCreation, stack >>

n_1 == /\ pc["k8s"] = "n_1"
       /\ IF apiServerReachable
             THEN /\ IF containerStatus = "completed" /\ ~taskResultExists
                        THEN /\ \/ /\ taskResultExists' = TRUE
                                   /\ \/ /\ taskResultContent' = "success"
                                      \/ /\ taskResultContent' = "failure"
                                      \/ /\ taskResultContent' = "error"
                                \/ /\ TRUE
                                   /\ UNCHANGED <<taskResultExists, taskResultContent>>
                        ELSE /\ TRUE
                             /\ UNCHANGED << taskResultExists, 
                                             taskResultContent >>
                  /\ IF taskResultExists' /\ ~taskResultSet
                        THEN /\ taskResultSet' = TRUE
                             /\ reconcileTriggered' = TRUE
                        ELSE /\ TRUE
                             /\ UNCHANGED << taskResultSet, reconcileTriggered >>
             ELSE /\ TRUE
                  /\ UNCHANGED << taskResultSet, taskResultExists, 
                                  taskResultContent, reconcileTriggered >>
       /\ pc' = [pc EXCEPT !["k8s"] = "n_2"]
       /\ UNCHANGED << wfStatus, nodeStatus, podStatus, containerStatus, 
                       createdPod, podExists, hasFinalizer, networkUp, 
                       apiServerReachable, readyNextNodeCreation, stack >>

n_2 == /\ pc["k8s"] = "n_2"
       /\ IF apiServerReachable
             THEN /\ \/ /\ IF taskResultExists /\ taskResultSet
                              THEN /\ taskResultExists' = FALSE
                              ELSE /\ TRUE
                                   /\ UNCHANGED taskResultExists
                     \/ /\ TRUE
                        /\ UNCHANGED taskResultExists
             ELSE /\ TRUE
                  /\ UNCHANGED taskResultExists
       /\ pc' = [pc EXCEPT !["k8s"] = "start_K"]
       /\ UNCHANGED << wfStatus, nodeStatus, podStatus, containerStatus, 
                       taskResultSet, createdPod, podExists, hasFinalizer, 
                       taskResultContent, reconcileTriggered, networkUp, 
                       apiServerReachable, readyNextNodeCreation, stack >>

done_K == /\ pc["k8s"] = "done_K"
          /\ Assert((TRUE), "Failure of assertion at line 183, column 15.")
          /\ pc' = [pc EXCEPT !["k8s"] = "Done"]
          /\ UNCHANGED << wfStatus, nodeStatus, podStatus, containerStatus, 
                          taskResultSet, taskResultExists, createdPod, 
                          podExists, hasFinalizer, taskResultContent, 
                          reconcileTriggered, networkUp, apiServerReachable, 
                          readyNextNodeCreation, stack >>

Kubernetes == start_K \/ n0 \/ n_1 \/ n_2 \/ done_K

start_P == /\ pc["cleanup"] = "start_P"
           /\ pc' = [pc EXCEPT !["cleanup"] = "cleanup0"]
           /\ UNCHANGED << wfStatus, nodeStatus, podStatus, containerStatus, 
                           taskResultSet, taskResultExists, createdPod, 
                           podExists, hasFinalizer, taskResultContent, 
                           reconcileTriggered, networkUp, apiServerReachable, 
                           readyNextNodeCreation, stack >>

cleanup0 == /\ pc["cleanup"] = "cleanup0"
            /\ IF apiServerReachable
                  THEN /\ IF nodeStatus \in {"succeeded", "failed", "error"} /\ hasFinalizer
                             THEN /\ stack' = [stack EXCEPT !["cleanup"] = << [ procedure |->  "processPodCleanup",
                                                                                pc        |->  "start_P" ] >>
                                                                            \o stack["cleanup"]]
                                  /\ pc' = [pc EXCEPT !["cleanup"] = "start_p"]
                             ELSE /\ pc' = [pc EXCEPT !["cleanup"] = "start_P"]
                                  /\ stack' = stack
                  ELSE /\ pc' = [pc EXCEPT !["cleanup"] = "start_P"]
                       /\ stack' = stack
            /\ UNCHANGED << wfStatus, nodeStatus, podStatus, containerStatus, 
                            taskResultSet, taskResultExists, createdPod, 
                            podExists, hasFinalizer, taskResultContent, 
                            reconcileTriggered, networkUp, apiServerReachable, 
                            readyNextNodeCreation >>

done_P == /\ pc["cleanup"] = "done_P"
          /\ Assert((TRUE), "Failure of assertion at line 198, column 15.")
          /\ pc' = [pc EXCEPT !["cleanup"] = "Done"]
          /\ UNCHANGED << wfStatus, nodeStatus, podStatus, containerStatus, 
                          taskResultSet, taskResultExists, createdPod, 
                          podExists, hasFinalizer, taskResultContent, 
                          reconcileTriggered, networkUp, apiServerReachable, 
                          readyNextNodeCreation, stack >>

PodCleanupController == start_P \/ cleanup0 \/ done_P

start == /\ pc["wf"] = "start"
         /\ stack' = [stack EXCEPT !["wf"] = << [ procedure |->  "assessNodeStatus",
                                                  pc        |->  "step2" ] >>
                                              \o stack["wf"]]
         /\ pc' = [pc EXCEPT !["wf"] = "start_"]
         /\ UNCHANGED << wfStatus, nodeStatus, podStatus, containerStatus, 
                         taskResultSet, taskResultExists, createdPod, 
                         podExists, hasFinalizer, taskResultContent, 
                         reconcileTriggered, networkUp, apiServerReachable, 
                         readyNextNodeCreation >>

step2 == /\ pc["wf"] = "step2"
         /\ stack' = [stack EXCEPT !["wf"] = << [ procedure |->  "createPod",
                                                  pc        |->  "step3" ] >>
                                              \o stack["wf"]]
         /\ pc' = [pc EXCEPT !["wf"] = "start_c"]
         /\ UNCHANGED << wfStatus, nodeStatus, podStatus, containerStatus, 
                         taskResultSet, taskResultExists, createdPod, 
                         podExists, hasFinalizer, taskResultContent, 
                         reconcileTriggered, networkUp, apiServerReachable, 
                         readyNextNodeCreation >>

step3 == /\ pc["wf"] = "step3"
         /\ stack' = [stack EXCEPT !["wf"] = << [ procedure |->  "updateWorkflowStatus",
                                                  pc        |->  "assess" ] >>
                                              \o stack["wf"]]
         /\ pc' = [pc EXCEPT !["wf"] = "start_u"]
         /\ UNCHANGED << wfStatus, nodeStatus, podStatus, containerStatus, 
                         taskResultSet, taskResultExists, createdPod, 
                         podExists, hasFinalizer, taskResultContent, 
                         reconcileTriggered, networkUp, apiServerReachable, 
                         readyNextNodeCreation >>

assess == /\ pc["wf"] = "assess"
          /\ reconcileTriggered' = FALSE
          /\ pc' = [pc EXCEPT !["wf"] = "start"]
          /\ UNCHANGED << wfStatus, nodeStatus, podStatus, containerStatus, 
                          taskResultSet, taskResultExists, createdPod, 
                          podExists, hasFinalizer, taskResultContent, 
                          networkUp, apiServerReachable, readyNextNodeCreation, 
                          stack >>

done == /\ pc["wf"] = "done"
        /\ Assert((TRUE), "Failure of assertion at line 217, column 15.")
        /\ pc' = [pc EXCEPT !["wf"] = "Done"]
        /\ UNCHANGED << wfStatus, nodeStatus, podStatus, containerStatus, 
                        taskResultSet, taskResultExists, createdPod, podExists, 
                        hasFinalizer, taskResultContent, reconcileTriggered, 
                        networkUp, apiServerReachable, readyNextNodeCreation, 
                        stack >>

Controller == start \/ step2 \/ step3 \/ assess \/ done

(* Allow infinite stuttering to prevent deadlock on termination. *)
Terminating == /\ \A self \in ProcSet: pc[self] = "Done"
               /\ UNCHANGED vars

Next == NetworkSimulator \/ Kubernetes \/ PodCleanupController
           \/ Controller
           \/ (\E self \in ProcSet:  \/ assessNodeStatus(self)
                                     \/ updateWorkflowStatus(self)
                                     \/ processPodCleanup(self) \/ createPod(self))
           \/ Terminating

Spec == Init /\ [][Next]_vars

Termination == <>(\A self \in ProcSet: pc[self] = "Done")

\* END TRANSLATION

\* User-specified correctness conditions

\* Condition 1: If pod completes (success or failure), workflow and node should eventually be marked complete
PodCompletionProperty ==
    [](podStatus \in {"failed", "succeeded"} => 
       (nodeStatus \in {"failed", "succeeded", "error"} /\ 
        wfStatus \in {"failed", "succeeded", "error"}))

\* Condition 2: If task result arrives, workflow and node should eventually be marked complete  
TaskResultCompletionProperty ==
    [](taskResultSet => 
       (nodeStatus \in {"failed", "succeeded", "error"} /\ 
        wfStatus \in {"failed", "succeeded", "error"}))

=============================================================

\* Network failure invariants
NetworkFailureInvariants == 
    /\ (apiServerReachable \in {TRUE, FALSE}) \* API server can be reachable or not

\* Write operation safety during network failures
WriteOperationSafety ==
    /\ [](~apiServerReachable => UNCHANGED <<wfStatus, createdPod, hasFinalizer>>) \* No writes during API failure
    /\ [](apiServerReachable) \* Controller can always read from cache and assess node status

\* Task result priority correctness (reads always work from cache)
TaskResultPriority ==
    /\ [](taskResultSet => 
         ((taskResultContent = "success" => nodeStatus = "succeeded") /\
          (taskResultContent = "failure" => nodeStatus = "failed") /\
          (taskResultContent = "error" => nodeStatus = "error")))

\* Eventual consistency - when API recovers, writes eventually succeed
EventualConsistency ==
    /\ []<>(apiServerReachable) \* API server eventually becomes reachable
    /\ [](apiServerReachable /\ nodeStatus \in {"succeeded", "failed", "error"} => 
         <>(wfStatus \in {"succeeded", "failed", "error"})) \* Workflow status eventually updated

\* Combined safety property
SafetyProperty ==
    /\ NetworkFailureInvariants
    /\ WriteOperationSafety
    /\ TaskResultPriority

\* Current bug: Workflow status stuck when no task result exists
WorkflowStatusBug ==
    /\ [](~taskResultSet => wfStatus = "pending") \* Workflow never leaves pending without task result
    /\ []((nodeStatus \in {"failed", "error"} /\ ~taskResultSet) => 
         [](wfStatus = "pending")) \* Workflow stuck pending even when node failed

\* Infinite reconciliation scenario
InfiniteReconciliation ==
    /\ []<>((podStatus = "failed" /\ ~taskResultExists) => 
         [](wfStatus = "pending" /\ nodeStatus = "failed")) \* Node failed but workflow stuck

\* What the correct behavior should be (for comparison)
CorrectBehaviorWould ==
    /\ [](nodeStatus \in {"succeeded", "failed", "error"} => 
         <>(wfStatus \in {"succeeded", "failed", "error"})) \* Workflow should eventually complete

\* Properties that demonstrate the bug
BugDemonstration ==
    /\ WorkflowStatusBug
    /\ InfiniteReconciliation

\* Inductive correctness property: When ready to create next node, we must have task result
InductiveCorrectnessProperty ==
    readyNextNodeCreation => taskResultExists

\* Combined correctness conditions
CorrectnessConditions ==
    /\ PodCompletionProperty
    /\ TaskResultCompletionProperty
    /\ InductiveCorrectnessProperty
