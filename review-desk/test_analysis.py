import importlib.util
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('review_findings',Path(__file__).resolve().parents[1]/'scripts/review_findings.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class AnalysisTests(unittest.TestCase):
    def test_no_proposal_from_missing_or_insufficient_measurements(self):
        r={'id':'run','cases':[{'id':'P01','title':'Navigation','samples':[]}],'proposals':[]}
        self.assertEqual(m.enrich(r)['proposals'],[])
        r['cases'][0]['samples']=[{'action':{'cpu_percent':30},'idle_before':{'cpu_percent':1}}]
        self.assertEqual(m.enrich(r)['proposals'],[])
    def test_investigation_is_data_linked_and_deduplicated(self):
        samples=[{'action':{'cpu_percent':n},'idle_before':{'cpu_percent':1}} for n in [20,21,19]]
        r={'id':'run-a','cases':[{'id':'P02','title':'Zoom','samples':samples}],'proposals':[]}
        m.enrich(r);m.enrich(r)
        self.assertEqual(len(r['proposals']),1)
        self.assertEqual(r['proposals'][0]['kind'],'Investigation')
        self.assertIn('20.00%',r['proposals'][0]['evidence'])
        self.assertEqual(r['analysis']['fully_verified_cases'],0)

if __name__=='__main__':unittest.main()
